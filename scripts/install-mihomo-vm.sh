#!/usr/bin/env bash
# mihomo 安装脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║      mihomo 安装脚本                 ║
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
    
    # 获取最新版本
    VERSION=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    [ -z "$VERSION" ] && msg_error "获取版本失败"
    
    # 下载
    URL="https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-${ARCH}-${VERSION}.gz"
    wget -q --show-progress "$URL" -O /tmp/mihomo.gz
    
    # 安装
    gunzip -f /tmp/mihomo.gz
    install -m 755 /tmp/mihomo /usr/local/bin/mihomo
    rm -f /tmp/mihomo
    
    msg_ok "mihomo 安装完成 (${VERSION})"
}

function setup_config() {
    msg_info "配置 mihomo..."
    
    mkdir -p /etc/mihomo/proxies
    
    # 从环境变量获取订阅
    SUBSCRIPTION_URL="${AUTO_SUBSCRIPTION_URL}"
    
    # 生成配置
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
    use:
      - airport
  
  - name: 自动选择
    type: url-test
    use:
      - airport
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
    
    msg_ok "服务启动完成"
}

function create_update_script() {
    msg_info "创建更新脚本..."
    
    mkdir -p /root/scripts
    
    cat > /root/scripts/update-mihomo.sh <<'EOF'
#!/bin/bash
echo "正在更新 mihomo 订阅..."
curl -fsSL -o /etc/mihomo/proxies/airport.yaml "$(grep 'url:' /etc/mihomo/config.yaml | awk '{print $2}' | tr -d '"')"
systemctl restart mihomo
echo "更新完成"
EOF

    chmod +x /root/scripts/update-mihomo.sh
    msg_ok "更新脚本创建完成"
}

function show_summary() {
    echo ""
    echo "══════════════════════════════════════"
    msg_ok "mihomo 安装完成！"
    echo "══════════════════════════════════════"
    echo ""
    echo "服务:"
    echo "  HTTP 代理: http://10.0.0.3:7890"
    echo "  SOCKS5: socks5://10.0.0.3:7891"
    echo "  API: http://10.0.0.3:9090"
    echo ""
    echo "管理:"
    echo "  状态: systemctl status mihomo"
    echo "  日志: journalctl -u mihomo -f"
    echo "  更新: /root/scripts/update-mihomo.sh"
    echo ""
    echo "测试:"
    echo "  curl -x http://10.0.0.3:7890 https://www.google.com -I"
    echo ""
}

function main() {
    show_header
    check_system
    detect_arch
    install_deps
    install_mihomo
    setup_config
    setup_service
    create_update_script
    show_summary
}

main
