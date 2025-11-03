#!/usr/bin/env bash

# mihomo 安装脚本 - Debian VM
# 支持智能配置选择

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║          mihomo 智能安装脚本                          ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行"
        exit 1
    fi
}

function check_debian() {
    if [ ! -f /etc/debian_version ]; then
        msg_error "仅支持 Debian 系统"
        exit 1
    fi
    msg_ok "系统检查通过"
}

function detect_arch() {
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64) MIHOMO_ARCH="linux-amd64" ;;
        aarch64) MIHOMO_ARCH="linux-arm64" ;;
        armv7l) MIHOMO_ARCH="linux-armv7" ;;
        *) msg_error "不支持的架构: ${ARCH}"; exit 1 ;;
    esac
    msg_ok "架构: ${ARCH}"
}

function install_dependencies() {
    msg_info "安装依赖..."
    apt-get update -qq
    apt-get install -y curl wget gzip ca-certificates >/dev/null 2>&1
    msg_ok "依赖安装完成"
}

function download_mihomo() {
    msg_info "获取最新版本..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        msg_error "获取版本失败"
        exit 1
    fi
    
    msg_info "下载 mihomo ${LATEST_VERSION}..."
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"
    
    if wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"; then
        gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
        chmod +x /usr/local/bin/mihomo
        rm -f /tmp/mihomo.gz
        msg_ok "下载完成"
    else
        msg_error "下载失败"
        exit 1
    fi
}

function create_directories() {
    msg_info "创建目录..."
    mkdir -p /etc/mihomo/{providers,ruleset}
    mkdir -p /opt/mihomo
    msg_ok "目录创建完成"
}

function choose_config_type() {
    # 支持环境变量自动配置（用于自动化部署）
    if [ -n "$AUTO_CONFIG_CHOICE" ]; then
        CONFIG_CHOICE=$AUTO_CONFIG_CHOICE
        msg_info "使用自动配置模式: 配置类型 = $CONFIG_CHOICE"
    else
        echo ""
        echo "请选择配置类型："
        echo ""
        echo "  1) 💡 智能配置（推荐）"
        echo "     - Smart 策略（自动选最快节点）"
        echo "     - 负载均衡和故障转移"
        echo "     - 动态规则更新"
        echo ""
        echo "  2) 📝 基础配置"
        echo "     - 简单代理配置"
        echo "     - 手动选择节点"
        echo ""
        read -p "请输入选择 [1/2]: " CONFIG_CHOICE
    fi
    
    case $CONFIG_CHOICE in
        1) CONFIG_TYPE="smart" ;;
        2) CONFIG_TYPE="basic" ;;
        *) CONFIG_TYPE="smart" ;;
    esac
}

function generate_smart_config() {
    msg_info "配置智能策略..."
    
    # 支持环境变量自动配置（用于自动化部署）
    if [ -n "$AUTO_SUBSCRIPTION_URL" ]; then
        SUBSCRIPTION_URL=$AUTO_SUBSCRIPTION_URL
        msg_info "使用自动配置的订阅地址"
    else
        echo ""
        read -p "请输入机场订阅地址: " SUBSCRIPTION_URL
    fi
    
    if [ -z "$SUBSCRIPTION_URL" ]; then
        msg_error "订阅地址不能为空"
        exit 1
    fi
    
    # 生成随机 API 密钥
    API_SECRET=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
    
    cat > /etc/mihomo/config.yaml <<EOF
port: 7890
socks-port: 7891
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
ipv6: false
external-controller: 0.0.0.0:9090
secret: "${API_SECRET}"

profile:
  store-selected: true
  store-fake-ip: true

dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: [223.5.5.5, 119.29.29.29]
  nameserver: 
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN

proxy-providers:
  main:
    type: http
    url: "${SUBSCRIPTION_URL}"
    interval: 3600
    path: ./providers/main.yaml
    health-check:
      enable: true
      interval: 600
      lazy: true
      url: http://www.gstatic.com/generate_204

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies: ["💡 智能", "⚖️ 负载", "🔄 转移", "🇭🇰 香港", "🇸🇬 新加坡", "🇯🇵 日本", "🇺🇸 美国", DIRECT]
  
  - name: "💡 智能"
    type: url-test
    tolerance: 50
    interval: 300
    url: http://www.gstatic.com/generate_204
    use: [main]
  
  - name: "⚖️ 负载"
    type: load-balance
    strategy: consistent-hashing
    interval: 300
    url: http://www.gstatic.com/generate_204
    use: [main]
  
  - name: "🔄 转移"
    type: fallback
    interval: 300
    url: http://www.gstatic.com/generate_204
    use: [main]
  
  - name: "🇭🇰 香港"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main]
    filter: "(?i)港|hk|hongkong"
  
  - name: "🇸🇬 新加坡"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main]
    filter: "(?i)新|坡|狮|sg|singapore"
  
  - name: "🇯🇵 日本"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main]
    filter: "(?i)日|jp|japan"
  
  - name: "🇺🇸 美国"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main]
    filter: "(?i)美|us|america|united"
  
  - name: "🌍 国外"
    type: select
    proxies: ["💡 智能", "⚖️ 负载", "🔄 转移", DIRECT]
  
  - name: "🎯 国内"
    type: select
    proxies: [DIRECT, "💡 智能"]
  
  - name: "🛡️ 拦截"
    type: select
    proxies: [REJECT, DIRECT]

rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400
  proxy:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400
  direct:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400
  gfw:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400
  cncidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400
  lancidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

rules:
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,reject,🛡️ 拦截
  - RULE-SET,proxy,🌍 国外
  - RULE-SET,gfw,🌍 国外
  - RULE-SET,direct,🎯 国内
  - RULE-SET,cncidr,🎯 国内,no-resolve
  - GEOIP,CN,🎯 国内
  - MATCH,🌍 国外
EOF
    
    msg_ok "智能配置已生成"
    echo "API 密钥: ${API_SECRET}"
}

function generate_basic_config() {
    msg_info "配置基础代理..."
    
    # 支持环境变量自动配置（用于自动化部署）
    if [ -n "$AUTO_SUBSCRIPTION_URL" ]; then
        SUBSCRIPTION_URL=$AUTO_SUBSCRIPTION_URL
        msg_info "使用自动配置的订阅地址"
    else
        echo ""
        read -p "请输入机场订阅地址: " SUBSCRIPTION_URL
    fi
    
    if [ -z "$SUBSCRIPTION_URL" ]; then
        msg_error "订阅地址不能为空"
        exit 1
    fi
    
    cat > /etc/mihomo/config.yaml <<EOF
port: 7890
socks-port: 7891
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 0.0.0.0:9090

dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  nameserver: [223.5.5.5, 119.29.29.29]

proxy-providers:
  main:
    type: http
    url: "${SUBSCRIPTION_URL}"
    interval: 3600
    path: ./providers/main.yaml

proxy-groups:
  - name: "🚀 代理"
    type: select
    use: [main]
  - name: "🎯 直连"
    type: select
    proxies: [DIRECT]

rules:
  - GEOIP,CN,🎯 直连
  - MATCH,🚀 代理
EOF
    
    msg_ok "基础配置已生成"
}

function create_systemd_service() {
    msg_info "创建系统服务..."
    
    cat > /etc/systemd/system/mihomo.service <<EOF
[Unit]
Description=mihomo Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/mihomo
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo -f /etc/mihomo/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    msg_ok "服务创建完成"
}

function create_update_script() {
    msg_info "创建更新脚本..."
    
    cat > /opt/mihomo/update-mihomo.sh <<'EOF'
#!/bin/bash
echo "更新 mihomo..."
LATEST=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
ARCH=$(uname -m | sed 's/x86_64/linux-amd64/;s/aarch64/linux-arm64/')
wget -q "https://github.com/MetaCubeX/mihomo/releases/download/${LATEST}/mihomo-${ARCH}-${LATEST}.gz" -O /tmp/mihomo.gz
systemctl stop mihomo
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm -f /tmp/mihomo.gz
systemctl start mihomo
echo "更新完成: ${LATEST}"
EOF
    
    chmod +x /opt/mihomo/update-mihomo.sh
    msg_ok "更新脚本已创建"
}

function start_service() {
    msg_info "启动服务..."
    
    systemctl enable mihomo >/dev/null 2>&1
    systemctl start mihomo
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败"
        journalctl -u mihomo -n 20
        exit 1
    fi
}

function show_result() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          mihomo 安装完成！                            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}服务信息:${NC}"
    echo "  HTTP 代理: http://10.0.0.3:7890"
    echo "  SOCKS5: socks5://10.0.0.3:7891"
    echo "  API: http://10.0.0.3:9090"
    
    if [ "$CONFIG_TYPE" = "smart" ]; then
        echo "  API 密钥: ${API_SECRET}"
    fi
    
    echo ""
    echo -e "${GREEN}配置类型:${NC}"
    if [ "$CONFIG_TYPE" = "smart" ]; then
        echo "  💡 智能配置 - 自动选择最优节点"
    else
        echo "  📝 基础配置 - 手动选择节点"
    fi
    
    echo ""
    echo -e "${BLUE}常用命令:${NC}"
    echo "  状态: systemctl status mihomo"
    echo "  日志: journalctl -u mihomo -f"
    echo "  重启: systemctl restart mihomo"
    echo "  更新: /opt/mihomo/update-mihomo.sh"
    echo ""
    echo -e "${BLUE}测试:${NC}"
    echo "  curl -x http://10.0.0.3:7890 https://www.google.com -I"
    echo ""
}

function main() {
    show_header
    check_root
    check_debian
    detect_arch
    install_dependencies
    download_mihomo
    create_directories
    choose_config_type
    
    if [ "$CONFIG_TYPE" = "smart" ]; then
        generate_smart_config
    else
        generate_basic_config
    fi
    
    create_systemd_service
    create_update_script
    start_service
    show_result
    
    msg_ok "🎉 完成！"
}

main
