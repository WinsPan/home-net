#!/usr/bin/env bash
# mihomo 独立安装脚本
# 在 mihomo VM 上直接运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/mihomo/install.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
function msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              mihomo 智能代理 - 快速安装                  ║
║                                                          ║
║  支持：智能分流 + 订阅管理 + 透明代理                     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_system() {
    msg_info "检查系统环境..."
    
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限运行（使用 sudo bash 或 root 用户）"
    fi
    
    if [ ! -f /etc/debian_version ]; then
        msg_error "仅支持 Debian 系统"
    fi
    
    msg_ok "系统检查通过"
}

function detect_arch() {
    case $(uname -m) in
        x86_64) ARCH="linux-amd64" ;;
        aarch64) ARCH="linux-arm64" ;;
        *) msg_error "不支持的架构: $(uname -m)" ;;
    esac
    msg_info "系统架构: $ARCH"
}

function install_deps() {
    msg_info "安装依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget unzip iptables &>/dev/null
    msg_ok "依赖安装完成"
}

function get_subscription() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_info "请输入机场订阅信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 优先使用环境变量（支持自动化安装）
    if [ -z "$SUBSCRIPTION_URL" ]; then
        read -p "机场订阅地址: " SUBSCRIPTION_URL
        while [ -z "$SUBSCRIPTION_URL" ]; do
            msg_error "订阅地址不能为空"
            read -p "机场订阅地址: " SUBSCRIPTION_URL
        done
    fi
    
    if [[ ! "$SUBSCRIPTION_URL" =~ ^https?:// ]]; then
        msg_error "订阅地址格式错误（需要 http:// 或 https://）: $SUBSCRIPTION_URL"
    fi
    
    echo ""
    msg_ok "订阅地址: $SUBSCRIPTION_URL"
    echo ""
}

function install_mihomo() {
    msg_info "安装 mihomo..."
    
    # 获取最新版本
    VERSION=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [ -z "$VERSION" ]; then
        msg_error "获取最新版本失败"
    fi
    msg_ok "最新版本: ${VERSION}"
    
    # 下载
    URL="https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-${ARCH}-${VERSION}.gz"
    msg_info "下载 mihomo..."
    
    if ! wget -q --show-progress "$URL" -O /tmp/mihomo.gz 2>&1; then
        msg_error "下载失败"
    fi
    
    if [ ! -s /tmp/mihomo.gz ]; then
        msg_error "下载的文件无效"
    fi
    
    # 解压安装
    gunzip -f /tmp/mihomo.gz || msg_error "解压失败"
    install -m 755 /tmp/mihomo /usr/local/bin/mihomo || msg_error "安装失败"
    rm -f /tmp/mihomo
    
    msg_ok "mihomo 安装完成 (${VERSION})"
}

function setup_config() {
    msg_info "生成配置文件..."
    
    mkdir -p /etc/mihomo/proxies
    
    cat > /etc/mihomo/config.yaml <<EOF
# mihomo 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 代理端口
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
external-ui: ui

# DNS 配置
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query

# 机场订阅
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

# 代理组
proxy-groups:
  - name: 🚀 节点选择
    type: select
    use: [airport]
  
  - name: ⚡ 自动选择
    type: url-test
    use: [airport]
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50

# 分流规则
rules:
  # 局域网
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  
  # 国内网站
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-KEYWORD,baidu,DIRECT
  - DOMAIN-KEYWORD,taobao,DIRECT
  - DOMAIN-KEYWORD,aliyun,DIRECT
  - GEOIP,CN,DIRECT
  
  # 其他流量走代理
  - MATCH,🚀 节点选择
EOF

    # 保存订阅地址
    echo "$SUBSCRIPTION_URL" > /etc/mihomo/.subscription
    
    msg_ok "配置文件生成完成"
}

function setup_service() {
    msg_info "配置 systemd 服务..."
    
    cat > /etc/systemd/system/mihomo.service <<EOF
[Unit]
Description=mihomo Proxy Service
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "mihomo 安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 服务信息："
    echo "   IP 地址: ${IP}"
    echo "   HTTP 代理: http://${IP}:7890"
    echo "   SOCKS5: socks5://${IP}:7891"
    echo "   管理面板: http://${IP}:9090"
    echo ""
    echo "🔧 管理命令："
    echo "   查看状态: systemctl status mihomo"
    echo "   重启服务: systemctl restart mihomo"
    echo "   查看日志: journalctl -u mihomo -f"
    echo "   停止服务: systemctl stop mihomo"
    echo ""
    echo "🧪 测试代理："
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "📝 配置文件："
    echo "   /etc/mihomo/config.yaml"
    echo ""
    echo "💡 下一步："
    echo "   1. 访问管理面板配置规则"
    echo "   2. 在客户端设置代理: http://${IP}:7890"
    echo "   3. 或配置 RouterOS 透明代理"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
