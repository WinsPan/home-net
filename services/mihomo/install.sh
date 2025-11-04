#!/usr/bin/env bash
# mihomo 快速安装脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║      mihomo 快速安装                 ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

function check_system() {
    [ "$EUID" -ne 0 ] && msg_error "需要 root 权限"
    [ ! -f /etc/debian_version ] && msg_error "仅支持 Debian 系统"
    msg_ok "系统检查通过"
}

function detect_arch() {
    case $(uname -m) in
        x86_64) ARCH="linux-amd64" ;;
        aarch64) ARCH="linux-arm64" ;;
        *) msg_error "不支持的架构" ;;
    esac
}

function install_deps() {
    msg_info "安装依赖..."
    apt-get update -qq
    apt-get install -y -qq curl wget unzip &>/dev/null
    msg_ok "依赖安装完成"
}

function install_mihomo() {
    msg_info "安装 mihomo..."
    
    VERSION=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [ -z "$VERSION" ]; then
        msg_error "获取版本失败"
    fi
    msg_ok "版本: ${VERSION}"
    
    URL="https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-${ARCH}-${VERSION}.gz"
    msg_info "下载 mihomo..."
    wget -q --show-progress "$URL" -O /tmp/mihomo.gz || msg_error "下载失败"
    
    gunzip -f /tmp/mihomo.gz || msg_error "解压失败"
    install -m 755 /tmp/mihomo /usr/local/bin/mihomo || msg_error "安装失败"
    rm -f /tmp/mihomo
    
    msg_ok "mihomo 安装完成 (${VERSION})"
}

function get_subscription() {
    read -p "机场订阅地址: " SUBSCRIPTION_URL
    while [ -z "$SUBSCRIPTION_URL" ]; do
        msg_error "订阅地址不能为空"
        read -p "机场订阅地址: " SUBSCRIPTION_URL
    done
    
    if [[ ! "$SUBSCRIPTION_URL" =~ ^https?:// ]]; then
        msg_error "订阅地址格式错误"
    fi
}

function setup_config() {
    msg_info "配置 mihomo..."
    
    mkdir -p /etc/mihomo/proxies
    
    cat > /etc/mihomo/config.yaml <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090

dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://dns.google/dns-query

proxy-providers:
  airport:
    type: http
    url: "${SUBSCRIPTION_URL}"
    interval: 86400
    path: ./proxies/airport.yaml
    health-check:
      enable: true
      url: http://www.gstatic.com/generate_204
      interval: 300

proxy-groups:
  - name: 节点选择
    type: select
    use: [airport]
  
  - name: 自动选择
    type: url-test
    use: [airport]
    url: http://www.gstatic.com/generate_204
    interval: 300

rules:
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-KEYWORD,baidu,DIRECT
  - DOMAIN-KEYWORD,taobao,DIRECT
  - GEOIP,CN,DIRECT
  - GEOIP,PRIVATE,DIRECT
  - MATCH,节点选择
EOF

    # 保存订阅地址
    echo "$SUBSCRIPTION_URL" > /etc/mihomo/.subscription
    
    msg_ok "配置完成"
}

function setup_service() {
    msg_info "配置服务..."
    
    cat > /etc/systemd/system/mihomo.service <<EOF
[Unit]
Description=mihomo Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/mihomo
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mihomo
    systemctl start mihomo
    
    sleep 3
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败，查看日志: journalctl -u mihomo -n 50"
    fi
}

function show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "════════════════════════════════════════"
    msg_ok "mihomo 安装完成！"
    echo "════════════════════════════════════════"
    echo ""
    echo "服务信息:"
    echo "  HTTP 代理: http://${IP}:7890"
    echo "  SOCKS5: socks5://${IP}:7891"
    echo "  管理面板: http://${IP}:9090"
    echo ""
    echo "管理命令:"
    echo "  状态: systemctl status mihomo"
    echo "  重启: systemctl restart mihomo"
    echo "  日志: journalctl -u mihomo -f"
    echo "  管理: bash services/mihomo/manage.sh"
    echo ""
    echo "测试代理:"
    echo "  curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
}

function main() {
    header
    check_system
    detect_arch
    get_subscription
    install_deps
    install_mihomo
    setup_config
    setup_service
    show_summary
}

main

