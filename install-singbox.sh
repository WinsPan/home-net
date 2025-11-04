#!/usr/bin/env bash
# sing-box 安装脚本（原生订阅）
# 使用 sing-box 格式订阅或通过 Sub-Store 转换后的订阅
# 调试：DEBUG=1 bash install-singbox.sh

[ "$DEBUG" = "1" ] && set -x

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

header() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  sing-box 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    [ "$EUID" -ne 0 ] && msg_error "需要 root 权限"
    msg_info "Root 权限检查通过"
}

check_system() {
    msg_info "检查系统..."
    [ ! -f /etc/os-release ] && msg_error "无法检测系统"
    
    . /etc/os-release
    msg_info "系统: $PRETTY_NAME"
    
    [[ "$ID" != "debian" ]] && [[ "$ID_LIKE" != *"debian"* ]] && msg_error "仅支持 Debian/Ubuntu"
    msg_ok "系统检查通过"
}

detect_arch() {
    local arch=$(uname -m)
    msg_info "架构: $arch"
    
    case $arch in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) msg_error "不支持的架构: $arch" ;;
    esac
    
    msg_ok "架构: $ARCH"
}

get_subscription() {
    echo ""
    
    if [ -n "$SUB_URL" ]; then
        msg_info "订阅地址: $SUB_URL"
    else
        if [ -t 0 ]; then
            read -p "订阅地址 (sing-box 格式): " SUB_URL
        else
            exec < /dev/tty
            read -p "订阅地址 (sing-box 格式): " SUB_URL
        fi
    fi
    
    [ -z "$SUB_URL" ] && msg_error "订阅地址不能为空"
    [[ ! "$SUB_URL" =~ ^https?:// ]] && msg_error "订阅地址格式错误"
    
    msg_ok "订阅地址已设置"
}

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update -qq || msg_error "apt-get update 失败"
    apt-get install -y -qq curl wget unzip gzip iptables jq
    
    msg_ok "依赖安装完成"
}

install_singbox() {
    msg_info "安装 sing-box..."
    
    VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
    [ -z "$VERSION" ] && msg_error "无法获取版本"
    
    URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${ARCH}.tar.gz"
    wget -q --show-progress "$URL" -O /tmp/singbox.tar.gz || msg_error "下载失败"
    
    tar -xzf /tmp/singbox.tar.gz -C /tmp/
    mv /tmp/sing-box-*/sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -rf /tmp/sing-box-* /tmp/singbox.tar.gz
    
    msg_ok "sing-box v${VERSION} 安装完成"
}

download_geofiles() {
    msg_info "下载地理数据库..."
    
    mkdir -p /usr/local/share/sing-box
    cd /usr/local/share/sing-box
    wget -q https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db
    wget -q https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db
    
    msg_ok "地理数据库完成"
}

setup_config() {
    msg_info "下载配置..."
    
    mkdir -p /etc/sing-box
    echo "$SUB_URL" > /etc/sing-box/.subscription
    
    curl -fsSL "$SUB_URL" -o /etc/sing-box/config.json || msg_error "下载配置失败"
    
    # 验证配置
    if ! sing-box check -c /etc/sing-box/config.json; then
        msg_error "配置文件格式错误，请确认订阅是 sing-box 格式"
    fi
    
    msg_ok "配置下载完成"
}

setup_service() {
    msg_info "配置服务..."
    
    cat > /etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建更新脚本
    cat > /usr/local/bin/update-singbox <<'EOF'
#!/bin/bash
# 更新 sing-box 订阅

SUB_URL=$(cat /etc/sing-box/.subscription)
echo "更新订阅: $SUB_URL"

curl -fsSL "$SUB_URL" -o /etc/sing-box/config.json.new || {
    echo "下载失败"
    exit 1
}

if sing-box check -c /etc/sing-box/config.json.new; then
    mv /etc/sing-box/config.json.new /etc/sing-box/config.json
    systemctl restart sing-box
    echo "更新成功"
else
    rm -f /etc/sing-box/config.json.new
    echo "配置无效"
    exit 1
fi
EOF
    
    chmod +x /usr/local/bin/update-singbox
    
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    sleep 3
    
    systemctl is-active --quiet sing-box || msg_error "sing-box 启动失败: journalctl -u sing-box -f"
    msg_ok "sing-box 服务启动成功"
}

show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 服务地址"
    echo "   sing-box 代理: http://${IP}:7890 (HTTP+SOCKS5)"
    echo ""
    echo "🔧 管理命令"
    echo "   systemctl status sing-box     # 状态"
    echo "   systemctl restart sing-box    # 重启"
    echo "   journalctl -u sing-box -f     # 日志"
    echo "   update-singbox                # 更新订阅"
    echo ""
    echo "🧪 测试代理"
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "💡 提示"
    echo "   - 订阅必须是 sing-box 格式"
    echo "   - Clash 订阅请使用 Sub-Store 转换"
    echo "   - Sub-Store 部署: install-substore-docker.sh"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    header
    
    msg_info "步骤 1/6: 检查权限..."
    check_root
    
    msg_info "步骤 2/6: 检查系统..."
    check_system
    
    msg_info "步骤 3/6: 检测架构..."
    detect_arch
    
    msg_info "步骤 4/6: 配置订阅..."
    get_subscription
    
    msg_info "步骤 5/6: 安装 sing-box..."
    install_deps
    install_singbox
    download_geofiles
    
    msg_info "步骤 6/6: 配置服务..."
    setup_config
    setup_service
    
    show_summary
}

set -E
trap 'msg_error "安装失败，请查看上述输出"' ERR

main
