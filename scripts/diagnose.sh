#!/bin/bash

# BoomDNS 故障诊断脚本
# 自动诊断常见问题并给出解决方案

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MIHOMO_IP="10.0.0.4"
ADGUARD_IP="10.0.0.5"

function msg_info() { echo -e "${BLUE}[诊断]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
function msg_error() { echo -e "${RED}[✗]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
function msg_solution() { echo -e "${CYAN}[解决方案]${NC} $1"; }

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║          BoomDNS 故障诊断工具                         ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
    echo "正在诊断系统问题..."
    echo ""
}

function check_internet() {
    msg_info "检查互联网连接..."
    
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        msg_ok "互联网连接正常"
        return 0
    else
        msg_error "无法连接互联网"
        msg_solution "请检查："
        echo "  1. 网线/WiFi 是否连接"
        echo "  2. 路由器是否正常工作"
        echo "  3. 运行: ping 8.8.8.8"
        return 1
    fi
}

function check_dns() {
    msg_info "检查 DNS 解析..."
    
    local dns_ok=0
    
    # 测试 DNS 解析
    if nslookup google.com >/dev/null 2>&1; then
        msg_ok "DNS 解析正常"
        dns_ok=1
    else
        msg_error "DNS 解析失败"
    fi
    
    # 检查当前 DNS 服务器
    CURRENT_DNS=$(nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}' | head -1)
    echo "  当前 DNS: $CURRENT_DNS"
    
    if [ $dns_ok -eq 0 ]; then
        msg_solution "解决方案："
        echo "  1. 检查 AdGuard Home 是否运行"
        echo "     ssh root@$ADGUARD_IP 'systemctl status AdGuardHome'"
        echo ""
        echo "  2. 临时使用公共 DNS"
        echo "     echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf"
        echo ""
        echo "  3. 检查 RouterOS DNS 配置"
        echo "     RouterOS: /ip dns print"
        return 1
    fi
    return 0
}

function check_mihomo() {
    msg_info "检查 mihomo 服务..."
    
    # 检查服务器可达性
    if ! ping -c 2 $MIHOMO_IP >/dev/null 2>&1; then
        msg_error "mihomo 服务器不可达 ($MIHOMO_IP)"
        msg_solution "解决方案："
        echo "  1. 检查 mihomo VM 是否启动"
        echo "     在 Proxmox 控制台检查 VM 状态"
        echo ""
        echo "  2. 检查 IP 配置"
        echo "     ssh root@$MIHOMO_IP 'ip addr show'"
        return 1
    fi
    msg_ok "mihomo 服务器可达"
    
    # 检查代理端口
    if ! timeout 3 bash -c "cat < /dev/null > /dev/tcp/$MIHOMO_IP/7890" 2>/dev/null; then
        msg_error "mihomo 代理端口未开放 (7890)"
        msg_solution "解决方案："
        echo "  1. 检查 mihomo 服务状态"
        echo "     ssh root@$MIHOMO_IP 'systemctl status mihomo'"
        echo ""
        echo "  2. 查看 mihomo 日志"
        echo "     ssh root@$MIHOMO_IP 'journalctl -u mihomo -n 50'"
        echo ""
        echo "  3. 重启 mihomo 服务"
        echo "     ssh root@$MIHOMO_IP 'systemctl restart mihomo'"
        return 1
    fi
    msg_ok "mihomo 代理端口开放"
    
    # 测试代理功能
    msg_info "测试代理功能..."
    if curl -x http://$MIHOMO_IP:7890 --connect-timeout 10 -s -o /dev/null https://www.google.com; then
        msg_ok "mihomo 代理功能正常"
        return 0
    else
        msg_error "mihomo 代理功能异常"
        msg_solution "解决方案："
        echo "  1. 检查订阅是否更新"
        echo "     ssh root@$MIHOMO_IP 'ls -lh /etc/mihomo/providers/'"
        echo ""
        echo "  2. 手动更新订阅"
        echo "     curl -X PUT http://$MIHOMO_IP:9090/providers/proxies/main-airport"
        echo ""
        echo "  3. 检查配置文件"
        echo "     ssh root@$MIHOMO_IP 'cat /etc/mihomo/config.yaml | grep url'"
        echo ""
        echo "  4. 查看详细日志"
        echo "     ssh root@$MIHOMO_IP 'journalctl -u mihomo -f'"
        return 1
    fi
}

function check_adguard() {
    msg_info "检查 AdGuard Home 服务..."
    
    # 检查服务器可达性
    if ! ping -c 2 $ADGUARD_IP >/dev/null 2>&1; then
        msg_error "AdGuard Home 服务器不可达 ($ADGUARD_IP)"
        msg_solution "解决方案："
        echo "  1. 检查 AdGuard Home VM 是否启动"
        echo "  2. 检查 IP 配置"
        return 1
    fi
    msg_ok "AdGuard Home 服务器可达"
    
    # 检查 DNS 端口
    if ! timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ADGUARD_IP/53" 2>/dev/null; then
        msg_error "AdGuard Home DNS 端口未开放 (53)"
        msg_solution "解决方案："
        echo "  1. 检查 AdGuard Home 服务"
        echo "     ssh root@$ADGUARD_IP 'systemctl status AdGuardHome'"
        echo ""
        echo "  2. 重启服务"
        echo "     ssh root@$ADGUARD_IP 'systemctl restart AdGuardHome'"
        return 1
    fi
    msg_ok "AdGuard Home DNS 端口开放"
    
    # 测试 DNS 解析
    if nslookup google.com $ADGUARD_IP >/dev/null 2>&1; then
        msg_ok "AdGuard Home DNS 解析正常"
        return 0
    else
        msg_error "AdGuard Home DNS 解析失败"
        msg_solution "解决方案："
        echo "  1. 检查 AdGuard Home 配置"
        echo "     浏览器访问: http://$ADGUARD_IP"
        echo ""
        echo "  2. 检查上游 DNS 设置"
        echo "     设置 → DNS 设置 → 上游 DNS 服务器"
        return 1
    fi
}

function check_ad_blocking() {
    msg_info "检查广告拦截功能..."
    
    # 测试广告域名
    if timeout 3 curl -s -o /dev/null -w "%{http_code}" "http://ad.doubleclick.net" | grep -q "000\|404"; then
        msg_ok "广告拦截功能正常"
        return 0
    else
        msg_warn "广告拦截可能未生效"
        msg_solution "建议检查："
        echo "  1. 访问 AdGuard Home 管理界面"
        echo "     http://$ADGUARD_IP"
        echo ""
        echo "  2. 检查过滤规则是否启用"
        echo "     过滤器 → DNS 封锁清单"
        echo ""
        echo "  3. 更新过滤规则"
        echo "     点击 '立即更新过滤器'"
        echo ""
        echo "  4. 清除 DNS 缓存"
        echo "     ipconfig /flushdns  (Windows)"
        echo "     sudo dscacheutil -flushcache  (macOS)"
        return 1
    fi
}

function show_system_info() {
    echo ""
    echo "════════════════════════════════════════════════════"
    echo ""
    msg_info "系统信息："
    echo ""
    
    echo "网络配置："
    echo "  mihomo:       $MIHOMO_IP:7890 (HTTP)"
    echo "  mihomo:       $MIHOMO_IP:7891 (SOCKS5)"
    echo "  AdGuard Home: $ADGUARD_IP:53 (DNS)"
    echo ""
    
    echo "当前 DNS:"
    CURRENT_DNS=$(nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}' | head -1)
    echo "  $CURRENT_DNS"
    echo ""
    
    echo "测试互联网连接:"
    if curl -s --connect-timeout 5 -o /dev/null https://www.baidu.com; then
        echo "  ✓ 国内网站可访问"
    else
        echo "  ✗ 国内网站无法访问"
    fi
    
    if curl -x http://$MIHOMO_IP:7890 --connect-timeout 5 -s -o /dev/null https://www.google.com; then
        echo "  ✓ 国外网站可访问（通过代理）"
    else
        echo "  ✗ 国外网站无法访问"
    fi
    echo ""
}

function show_common_solutions() {
    echo "════════════════════════════════════════════════════"
    echo ""
    msg_info "常见问题快速解决："
    echo ""
    
    echo "1. 无法上网"
    echo "   → 检查网络连接和 DNS 配置"
    echo "   → 临时禁用 DNS 劫持测试"
    echo ""
    
    echo "2. 代理不工作"
    echo "   → 检查 mihomo 服务: systemctl status mihomo"
    echo "   → 更新订阅: curl -X PUT http://$MIHOMO_IP:9090/providers/proxies/main-airport"
    echo ""
    
    echo "3. 广告未拦截"
    echo "   → 访问 http://$ADGUARD_IP 检查规则"
    echo "   → 更新过滤规则"
    echo "   → 清除浏览器缓存"
    echo ""
    
    echo "4. DNS 解析失败"
    echo "   → 检查 AdGuard Home: systemctl status AdGuardHome"
    echo "   → 检查 RouterOS DNS: /ip dns print"
    echo ""
    
    echo "详细文档："
    echo "  https://github.com/WinsPan/home-net/blob/main/GUIDE.md"
    echo ""
}

function main() {
    show_header
    
    local has_error=0
    
    check_internet || has_error=1
    echo ""
    
    check_dns || has_error=1
    echo ""
    
    check_mihomo || has_error=1
    echo ""
    
    check_adguard || has_error=1
    echo ""
    
    check_ad_blocking || has_error=1
    
    show_system_info
    
    if [ $has_error -eq 1 ]; then
        show_common_solutions
    else
        echo "════════════════════════════════════════════════════"
        echo ""
        msg_ok "所有检查通过！系统运行正常"
        echo ""
        echo "管理界面："
        echo "  mihomo:       http://$MIHOMO_IP:9090"
        echo "  AdGuard Home: http://$ADGUARD_IP"
        echo ""
    fi
}

main

