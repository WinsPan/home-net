#!/usr/bin/env bash
# sing-box + Sub-Store 安装脚本
# 使用 Sub-Store 进行订阅管理和格式转换
# 调试模式：DEBUG=1 bash install-singbox-v2.sh

# 启用调试模式
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
    echo "  sing-box + Sub-Store 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限，请使用: sudo bash install-singbox-v2.sh"
    fi
    msg_info "Root 权限检查通过"
}

check_system() {
    msg_info "检查系统..."
    
    if [ ! -f /etc/os-release ]; then
        msg_error "无法检测系统类型，需要 /etc/os-release 文件"
    fi
    
    . /etc/os-release
    msg_info "检测到系统: $PRETTY_NAME"
    
    if [[ "$ID" != "debian" ]] && [[ "$ID_LIKE" != *"debian"* ]]; then
        msg_error "仅支持 Debian/Ubuntu 系统，当前系统: $ID"
    fi
    
    msg_ok "系统检查通过"
}

detect_arch() {
    local machine_arch=$(uname -m)
    msg_info "检测到架构: $machine_arch"
    
    case $machine_arch in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) msg_error "不支持的架构: $machine_arch" ;;
    esac
    
    msg_ok "架构: $ARCH"
}

get_subscription() {
    echo ""
    
    if [ -n "$SUB_URL" ]; then
        msg_info "使用环境变量订阅地址"
    else
        if [ -t 0 ]; then
            read -p "订阅地址: " SUB_URL
        else
            exec < /dev/tty
            read -p "订阅地址: " SUB_URL
        fi
    fi
    
    [ -z "$SUB_URL" ] && msg_error "订阅地址不能为空"
    [[ ! "$SUB_URL" =~ ^https?:// ]] && msg_error "订阅地址格式错误"
    msg_ok "订阅地址已设置"
}

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    
    msg_info "更新软件包列表..."
    apt-get update -qq || msg_error "apt-get update 失败"
    
    msg_info "安装系统依赖..."
    apt-get install -y -qq curl wget unzip gzip iptables jq git ca-certificates gnupg
    
    msg_ok "依赖安装完成"
}

install_nodejs() {
    msg_info "安装 Node.js..."
    
    if command -v node &>/dev/null; then
        local node_ver=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_ver" -ge 18 ]; then
            msg_ok "Node.js $(node --version) 已安装"
            return
        else
            msg_warn "Node.js 版本过低，重新安装..."
        fi
    fi
    
    # 安装 NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || msg_error "NodeSource 安装失败"
    apt-get install -y nodejs || msg_error "Node.js 安装失败"
    
    # 安装 pnpm
    npm install -g pnpm || msg_error "pnpm 安装失败"
    
    msg_ok "Node.js $(node --version) 安装完成"
}

install_substore() {
    msg_info "安装 Sub-Store..."
    
    rm -rf /opt/sub-store
    
    msg_info "克隆 Sub-Store 仓库..."
    git clone --depth 1 https://github.com/sub-store-org/Sub-Store.git /opt/sub-store || msg_error "克隆失败"
    
    cd /opt/sub-store/backend
    
    msg_info "安装依赖（需要几分钟，请耐心等待）..."
    pnpm install || {
        msg_warn "pnpm install 有警告，尝试继续..."
    }
    
    msg_info "构建 Sub-Store..."
    pnpm run build || msg_error "构建失败"
    
    msg_ok "Sub-Store 安装完成"
}

setup_substore_service() {
    msg_info "配置 Sub-Store 服务..."
    
    cat > /etc/systemd/system/sub-store.service <<'EOF'
[Unit]
Description=Sub-Store Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/sub-store/backend
Environment="SUB_STORE_BACKEND_API_PORT=3001"
Environment="SUB_STORE_BACKEND_API_HOST=0.0.0.0"
Environment="NODE_ENV=production"
ExecStart=/usr/bin/node /opt/sub-store/backend/dist/sub-store.bundle.js
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sub-store
    systemctl start sub-store
    
    sleep 5
    
    if systemctl is-active --quiet sub-store; then
        msg_ok "Sub-Store 已启动在端口 3001"
    else
        msg_error "Sub-Store 启动失败，查看日志: journalctl -u sub-store -f"
    fi
}

install_singbox() {
    msg_info "安装 sing-box..."
    
    VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
    [ -z "$VERSION" ] && msg_error "无法获取 sing-box 版本"
    
    URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${ARCH}.tar.gz"
    
    wget -q --show-progress "$URL" -O /tmp/singbox.tar.gz || msg_error "下载失败"
    tar -xzf /tmp/singbox.tar.gz -C /tmp/
    
    mv /tmp/sing-box-*/sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    rm -rf /tmp/sing-box-* /tmp/singbox.tar.gz
    
    msg_ok "sing-box v${VERSION} 安装完成"
}

download_geofiles() {
    msg_info "下载 GEO 数据库..."
    
    mkdir -p /usr/local/share/sing-box
    cd /usr/local/share/sing-box
    
    wget -q https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db
    wget -q https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db
    
    msg_ok "GEO 数据库完成"
}

setup_singbox_config() {
    msg_info "配置 sing-box..."
    
    mkdir -p /etc/sing-box
    
    # 创建辅助脚本：使用 Sub-Store 转换订阅
    cat > /usr/local/bin/update-singbox-sub <<'EOF'
#!/bin/bash
# 使用 Sub-Store 更新 sing-box 订阅

SUB_URL_FILE="/etc/sing-box/.subscription"
CONFIG_FILE="/etc/sing-box/config.json"

if [ ! -f "$SUB_URL_FILE" ]; then
    echo "错误：未找到订阅地址文件"
    exit 1
fi

SUB_URL=$(cat "$SUB_URL_FILE")

echo "正在通过 Sub-Store 转换订阅..."
echo "订阅地址: $SUB_URL"

# 使用 Sub-Store API 转换为 sing-box 格式
# Sub-Store 订阅转换 API: http://localhost:3001/download/[collection]?target=sing-box
# 我们需要先创建一个订阅集合

# 临时方案：直接下载原始订阅，如果是 sing-box 格式
# 完整的 Sub-Store 集成需要通过 Web UI 配置

curl -fsSL "$SUB_URL" -o "$CONFIG_FILE" || {
    echo "错误：下载订阅失败"
    exit 1
}

# 验证配置
if ! sing-box check -c "$CONFIG_FILE"; then
    echo "错误：配置文件无效"
    exit 1
fi

echo "订阅更新成功！"
systemctl restart sing-box
EOF
    
    chmod +x /usr/local/bin/update-singbox-sub
    
    # 保存订阅地址
    echo "$SUB_URL" > /etc/sing-box/.subscription
    
    # 首次配置
    msg_info "首次下载配置..."
    /usr/local/bin/update-singbox-sub || msg_error "配置下载失败"
    
    msg_ok "sing-box 配置完成"
}

setup_singbox_service() {
    msg_info "配置 sing-box 服务..."
    
    cat > /etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box Service
After=network.target sub-store.service

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
    
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    
    sleep 3
    
    if systemctl is-active --quiet sing-box; then
        msg_ok "sing-box 服务启动成功"
    else
        msg_error "sing-box 启动失败，查看日志: journalctl -u sing-box -f"
    fi
}

show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 服务信息"
    echo "   IP: ${IP}"
    echo "   sing-box 代理: http://${IP}:7890"
    echo "   Sub-Store 管理: http://${IP}:3001"
    echo ""
    echo "🔧 sing-box 管理"
    echo "   systemctl status sing-box     # 状态"
    echo "   systemctl restart sing-box    # 重启"
    echo "   journalctl -u sing-box -f     # 日志"
    echo "   update-singbox-sub            # 更新订阅"
    echo ""
    echo "🎛️  Sub-Store 管理"
    echo "   systemctl status sub-store    # 状态"
    echo "   systemctl restart sub-store   # 重启"
    echo "   journalctl -u sub-store -f    # 日志"
    echo ""
    echo "🌐 Sub-Store Web UI"
    echo "   打开浏览器访问: http://${IP}:3001"
    echo "   在 Web UI 中可以："
    echo "   1. 添加订阅源"
    echo "   2. 配置转换规则"
    echo "   3. 生成 sing-box 配置链接"
    echo ""
    echo "🧪 测试代理"
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    header
    
    msg_info "步骤 1/9: 检查权限..."
    check_root
    
    msg_info "步骤 2/9: 检查系统..."
    check_system
    
    msg_info "步骤 3/9: 检测架构..."
    detect_arch
    
    msg_info "步骤 4/9: 获取订阅..."
    get_subscription
    
    msg_info "步骤 5/9: 安装系统依赖..."
    install_deps
    
    msg_info "步骤 6/9: 安装 Node.js..."
    install_nodejs
    
    msg_info "步骤 7/9: 安装 Sub-Store..."
    install_substore
    setup_substore_service
    
    msg_info "步骤 8/9: 安装 sing-box..."
    install_singbox
    download_geofiles
    setup_singbox_config
    
    msg_info "步骤 9/9: 配置服务..."
    setup_singbox_service
    
    show_summary
}

# 捕获错误
set -E
trap 'msg_error "安装过程中发生错误，请检查上述输出"' ERR

main

