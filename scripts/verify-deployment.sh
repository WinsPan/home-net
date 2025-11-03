#!/bin/bash

# BoomDNS 部署验证脚本
# 自动测试所有功能是否正常

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MIHOMO_IP="10.0.0.4"
ADGUARD_IP="10.0.0.5"
ROUTEROS_IP="10.0.0.2"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

function msg_info() { echo -e "${BLUE}[测试]${NC} $1"; }
function msg_pass() { echo -e "${GREEN}[✓]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
function msg_fail() { echo -e "${RED}[✗]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
function msg_warn() { echo -e "${YELLOW}[!]${NC} $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║          BoomDNS 部署验证工具                         ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function test_network() {
    msg_info "测试网络连接..."
    
    # 测试互联网连接
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        msg_pass "互联网连接正常"
    else
        msg_fail "无法连接互联网"
        return
    fi
}

function test_mihomo() {
    msg_info "测试 mihomo 服务..."
    
    # 测试 mihomo 服务器可达
    if ping -c 2 $MIHOMO_IP >/dev/null 2>&1; then
        msg_pass "mihomo 服务器可达 ($MIHOMO_IP)"
    else
        msg_fail "mihomo 服务器不可达 ($MIHOMO_IP)"
        return
    fi
    
    # 测试 HTTP 代理端口
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$MIHOMO_IP/7890" 2>/dev/null; then
        msg_pass "mihomo HTTP 端口开放 (7890)"
    else
        msg_fail "mihomo HTTP 端口未开放 (7890)"
    fi
    
    # 测试 SOCKS5 端口
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$MIHOMO_IP/7891" 2>/dev/null; then
        msg_pass "mihomo SOCKS5 端口开放 (7891)"
    else
        msg_warn "mihomo SOCKS5 端口未开放 (7891)"
    fi
    
    # 测试 API 端口
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$MIHOMO_IP/9090" 2>/dev/null; then
        msg_pass "mihomo API 端口开放 (9090)"
    else
        msg_warn "mihomo API 端口未开放 (9090)"
    fi
    
    # 测试代理功能
    msg_info "测试代理连接..."
    if curl -x http://$MIHOMO_IP:7890 --connect-timeout 10 -s -o /dev/null -w "%{http_code}" https://www.google.com | grep -q "200\|301\|302"; then
        msg_pass "mihomo 代理功能正常"
    else
        msg_fail "mihomo 代理功能异常"
    fi
}

function test_adguard() {
    msg_info "测试 AdGuard Home 服务..."
    
    # 测试 AdGuard Home 服务器可达
    if ping -c 2 $ADGUARD_IP >/dev/null 2>&1; then
        msg_pass "AdGuard Home 服务器可达 ($ADGUARD_IP)"
    else
        msg_fail "AdGuard Home 服务器不可达 ($ADGUARD_IP)"
        return
    fi
    
    # 测试 DNS 端口
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ADGUARD_IP/53" 2>/dev/null; then
        msg_pass "AdGuard Home DNS 端口开放 (53)"
    else
        msg_fail "AdGuard Home DNS 端口未开放 (53)"
    fi
    
    # 测试 Web 管理端口
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ADGUARD_IP/80" 2>/dev/null || \
       timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ADGUARD_IP/3000" 2>/dev/null; then
        msg_pass "AdGuard Home Web 端口开放"
    else
        msg_warn "AdGuard Home Web 端口未开放"
    fi
    
    # 测试 DNS 解析
    msg_info "测试 DNS 解析..."
    if nslookup google.com $ADGUARD_IP >/dev/null 2>&1; then
        msg_pass "DNS 解析正常 (google.com)"
    else
        msg_fail "DNS 解析失败"
    fi
    
    if nslookup baidu.com $ADGUARD_IP >/dev/null 2>&1; then
        msg_pass "DNS 解析正常 (baidu.com)"
    else
        msg_fail "DNS 解析失败"
    fi
}

function test_routeros() {
    msg_info "测试 RouterOS 连接..."
    
    # 测试 RouterOS 可达
    if ping -c 2 $ROUTEROS_IP >/dev/null 2>&1; then
        msg_pass "RouterOS 可达 ($ROUTEROS_IP)"
    else
        msg_warn "RouterOS 不可达 ($ROUTEROS_IP) - 如果 IP 不同请忽略"
        return
    fi
}

function test_dns_hijack() {
    msg_info "测试 DNS 劫持..."
    
    # 检查当前 DNS 服务器
    CURRENT_DNS=$(nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}' | head -1)
    
    if [[ "$CURRENT_DNS" == "$ADGUARD_IP" ]]; then
        msg_pass "DNS 劫持生效 (使用 $ADGUARD_IP)"
    else
        msg_warn "DNS 劫持未生效 (当前使用 $CURRENT_DNS)"
    fi
}

function test_ad_blocking() {
    msg_info "测试广告拦截..."
    
    # 测试广告域名
    AD_DOMAINS=("ad.doubleclick.net" "ads.google.com" "pagead2.googlesyndication.com")
    BLOCKED=0
    
    for domain in "${AD_DOMAINS[@]}"; do
        if timeout 3 curl -s -o /dev/null -w "%{http_code}" "http://$domain" | grep -q "000\|404"; then
            BLOCKED=$((BLOCKED + 1))
        fi
    done
    
    if [ $BLOCKED -gt 0 ]; then
        msg_pass "广告拦截功能正常 (已拦截 $BLOCKED/${#AD_DOMAINS[@]} 个测试域名)"
    else
        msg_warn "广告拦截可能未生效"
    fi
}

function test_smart_routing() {
    msg_info "测试智能分流..."
    
    # 测试国内网站（应该直连）
    msg_info "测试国内网站访问..."
    if curl -x http://$MIHOMO_IP:7890 --connect-timeout 10 -s -o /dev/null https://www.baidu.com; then
        msg_pass "国内网站可访问 (baidu.com)"
    else
        msg_warn "国内网站访问异常"
    fi
    
    # 测试国外网站（应该走代理）
    msg_info "测试国外网站访问..."
    if curl -x http://$MIHOMO_IP:7890 --connect-timeout 10 -s -o /dev/null https://www.google.com; then
        msg_pass "国外网站可访问 (google.com)"
    else
        msg_warn "国外网站访问异常"
    fi
}

function show_summary() {
    echo ""
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "测试完成！"
    echo ""
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ 所有测试通过！部署成功！${NC}"
        echo ""
        echo "下一步："
        echo "  - 访问 http://$MIHOMO_IP:9090 管理 mihomo"
        echo "  - 访问 http://$ADGUARD_IP 管理 AdGuard Home"
        echo "  - 在设备上设置代理: $MIHOMO_IP:7890"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠ 测试基本通过，但有些警告${NC}"
        echo ""
        echo "建议检查："
        echo "  - 查看上面的警告信息"
        echo "  - 运行: journalctl -u mihomo -n 50"
        echo "  - 运行: journalctl -u AdGuardHome -n 50"
    else
        echo -e "${RED}✗ 部分测试失败${NC}"
        echo ""
        echo "故障排查："
        echo "  1. 检查服务状态"
        echo "     ssh root@$MIHOMO_IP 'systemctl status mihomo'"
        echo "     ssh root@$ADGUARD_IP 'systemctl status AdGuardHome'"
        echo ""
        echo "  2. 查看日志"
        echo "     ssh root@$MIHOMO_IP 'journalctl -u mihomo -n 50'"
        echo "     ssh root@$ADGUARD_IP 'journalctl -u AdGuardHome -n 50'"
        echo ""
        echo "  3. 查看详细文档"
        echo "     https://github.com/WinsPan/home-net/blob/main/GUIDE.md"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════"
}

function main() {
    show_header
    
    echo "开始验证 BoomDNS 部署..."
    echo ""
    
    test_network
    echo ""
    
    test_mihomo
    echo ""
    
    test_adguard
    echo ""
    
    test_routeros
    echo ""
    
    test_dns_hijack
    echo ""
    
    test_ad_blocking
    echo ""
    
    test_smart_routing
    
    show_summary
}

main

