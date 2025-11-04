#!/usr/bin/env bash
# sing-box 自动安装脚本
# 支持：内置转换器 / Sub-Store 管理
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

choose_mode() {
    echo ""
    
    # 检查系统内存
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    msg_info "系统内存: ${total_mem}MB"
    
    if [ "$total_mem" -lt 1500 ]; then
        msg_warn "⚠️  内存不足 2GB，建议使用快速模式"
    fi
    
    echo ""
    echo "请选择安装模式："
    echo "  1) 快速模式 - 内置转换器（推荐单订阅，内存要求低）"
    echo "  2) 完整模式 - Sub-Store 管理（推荐多订阅，需要 ≥2GB 内存）"
    echo ""
    
    if [ -n "$INSTALL_MODE" ]; then
        MODE="$INSTALL_MODE"
        msg_info "使用环境变量模式: $MODE"
    else
        if [ -t 0 ]; then
            read -p "选择 [1]: " MODE
        else
            exec < /dev/tty
            read -p "选择 [1]: " MODE
        fi
    fi
    
    MODE=${MODE:-1}
    
    if [ "$MODE" = "2" ]; then
        if [ "$total_mem" -lt 1500 ]; then
            msg_warn "警告：内存可能不足，Sub-Store 构建可能失败"
            echo ""
            read -p "是否继续？(y/N): " confirm
            confirm=${confirm:-N}
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                msg_info "已取消，将使用快速模式"
                MODE=1
                USE_SUBSTORE=false
            else
                USE_SUBSTORE=true
            fi
        else
            USE_SUBSTORE=true
        fi
        
        if [ "$USE_SUBSTORE" = "true" ]; then
            msg_ok "将安装 Sub-Store 完整版"
        else
            msg_ok "将使用内置转换器"
        fi
    else
        USE_SUBSTORE=false
        msg_ok "将使用内置转换器"
    fi
}

get_subscription() {
    echo ""
    
    if [ -n "$SUB_URL" ]; then
        msg_info "订阅地址: $SUB_URL"
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
    
    if [ "$USE_SUBSTORE" = "false" ]; then
        echo ""
        echo "订阅格式："
        echo "  1) sing-box 格式（直接使用）"
        echo "  2) Clash 格式（自动转换）"
        echo ""
        
        if [ -n "$SUB_TYPE" ]; then
            msg_info "使用环境变量类型: $SUB_TYPE"
        else
            if [ -t 0 ]; then
                read -p "选择 [2]: " SUB_TYPE
            else
                exec < /dev/tty
                read -p "选择 [2]: " SUB_TYPE
            fi
        fi
        
        SUB_TYPE=${SUB_TYPE:-2}
        USE_CONVERTER=$( [ "$SUB_TYPE" = "2" ] && echo "true" || echo "false" )
    fi
    
    msg_ok "配置完成"
}

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update -qq || msg_error "apt-get update 失败"
    
    if [ "$USE_SUBSTORE" = "true" ]; then
        apt-get install -y -qq curl wget unzip gzip iptables jq git ca-certificates gnupg
    else
        apt-get install -y -qq curl wget unzip gzip iptables jq python3 python3-yaml
    fi
    
    msg_ok "依赖安装完成"
}

install_nodejs() {
    msg_info "安装 Node.js..."
    
    if command -v node &>/dev/null; then
        local ver=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$ver" -ge 18 ]; then
            msg_ok "Node.js $(node --version) 已安装"
            return
        fi
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || msg_error "NodeSource 失败"
    apt-get install -y nodejs || msg_error "Node.js 安装失败"
    npm install -g pnpm || msg_error "pnpm 安装失败"
    
    msg_ok "Node.js $(node --version) 安装完成"
}

install_substore() {
    msg_info "安装 Sub-Store..."
    
    rm -rf /opt/sub-store
    git clone --depth 1 https://github.com/sub-store-org/Sub-Store.git /opt/sub-store || msg_error "克隆失败"
    
    cd /opt/sub-store/backend
    msg_info "安装依赖（需要几分钟）..."
    pnpm install || msg_warn "pnpm install 有警告"
    
    msg_info "构建（增加内存限制）..."
    
    # 创建 .eslintignore 忽略所有文件
    cat > /opt/sub-store/backend/.eslintignore <<'EOF'
**/*
*
src/**/*
EOF
    
    msg_info "已禁用 ESLint 检查"
    
    # 增加 Node.js 内存限制到 4GB
    export NODE_OPTIONS="--max-old-space-size=4096"
    msg_info "已设置 Node.js 内存限制: 4GB"
    
    # 尝试构建
    if pnpm run build 2>&1 | tee /tmp/substore-build.log; then
        msg_ok "构建成功"
    else
        msg_warn "构建出现错误，检查产物..."
        # 检查是否有构建产物
        if [ -f "dist/sub-store.bundle.js" ] && [ -s "dist/sub-store.bundle.js" ]; then
            local size=$(stat -c%s "dist/sub-store.bundle.js" 2>/dev/null || stat -f%z "dist/sub-store.bundle.js" 2>/dev/null || echo 0)
            if [ "$size" -gt 100000 ]; then
                msg_ok "构建产物存在且大小正常 (${size} bytes)，继续..."
            else
                msg_error "构建产物太小，构建失败"
            fi
        else
            msg_error "构建失败，未找到有效产物。查看日志: /tmp/substore-build.log"
        fi
    fi
    
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
    
    systemctl is-active --quiet sub-store || msg_error "Sub-Store 启动失败: journalctl -u sub-store -f"
    msg_ok "Sub-Store 已启动 (端口 3001)"
}

create_converter() {
    msg_info "创建转换工具..."
    
    mkdir -p /opt/converter
    cat > /opt/converter/convert.py <<'EOF'
#!/usr/bin/env python3
import json, yaml, sys, urllib.request, base64

def convert(data):
    # Base64 解码
    try:
        data = base64.b64decode(data).decode('utf-8')
    except:
        pass
    
    # 解析 YAML
    try:
        c = yaml.safe_load(data)
    except Exception as e:
        print(f"错误: YAML解析失败 - {e}", file=sys.stderr)
        sys.exit(1)
    
    if not isinstance(c, dict):
        print(f"错误: 订阅格式错误，得到 {type(c).__name__}", file=sys.stderr)
        sys.exit(1)
    
    if 'proxies' not in c or not c['proxies']:
        print(f"错误: 没有找到节点，可用字段: {list(c.keys())}", file=sys.stderr)
        sys.exit(1)
    
    # 转换为 sing-box
    sb = {
        "log": {"level": "info"},
        "dns": {
            "servers": [
                {"tag": "dns_proxy", "address": "https://1.1.1.1/dns-query", "detour": "proxy"},
                {"tag": "dns_direct", "address": "https://223.5.5.5/dns-query", "detour": "direct"}
            ],
            "rules": [{"geosite": "cn", "server": "dns_direct"}],
            "final": "dns_proxy"
        },
        "inbounds": [{"type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 7890, "sniff": True}],
        "outbounds": [],
        "route": {
            "rules": [
                {"protocol": "dns", "outbound": "dns-out"},
                {"geosite": "cn", "geoip": ["cn", "private"], "outbound": "direct"},
                {"geosite": "category-ads-all", "outbound": "block"}
            ],
            "final": "proxy",
            "auto_detect_interface": True
        }
    }
    
    nodes, tags = [], []
    for p in c['proxies']:
        t = p.get('type', '').lower()
        o = {"tag": p['name'], "type": t, "server": p['server'], "server_port": p['port']}
        
        if t in ['ss', 'shadowsocks']:
            o.update({"method": p['cipher'], "password": p['password']})
        elif t == 'vmess':
            o.update({"uuid": p['uuid'], "security": p.get('cipher', 'auto'), "alter_id": p.get('alterId', 0)})
            if p.get('tls'): o['tls'] = {"enabled": True, "server_name": p.get('servername', p['server'])}
        elif t == 'trojan':
            o['password'] = p['password']
            if p.get('sni'): o['tls'] = {"enabled": True, "server_name": p['sni']}
        
        nodes.append(o)
        tags.append(p['name'])
    
    sb['outbounds'] = [
        {"type": "selector", "tag": "proxy", "outbounds": ["auto"] + tags + ["direct"], "default": "auto"},
        {"type": "urltest", "tag": "auto", "outbounds": tags, "url": "https://www.gstatic.com/generate_204", "interval": "10m"}
    ] + nodes + [
        {"type": "direct", "tag": "direct"},
        {"type": "block", "tag": "block"},
        {"type": "dns", "tag": "dns-out"}
    ]
    
    return json.dumps(sb, indent=2)

if __name__ == '__main__':
    url = sys.argv[1] if len(sys.argv) > 1 else input("订阅URL: ")
    with urllib.request.urlopen(url) as r:
        print(convert(r.read().decode()))
EOF
    
    chmod +x /opt/converter/convert.py
    msg_ok "转换工具创建完成"
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
    msg_info "生成配置..."
    
    mkdir -p /etc/sing-box
    echo "$SUB_URL" > /etc/sing-box/.subscription
    
    if [ "$USE_SUBSTORE" = "true" ]; then
        msg_info "下载配置（请稍后在 Sub-Store Web UI 中配置订阅）..."
        # 临时配置，用户需要通过 Web UI 配置
        curl -fsSL "$SUB_URL" -o /etc/sing-box/config.json || {
            msg_warn "临时配置下载失败，将在 Sub-Store 配置后更新"
            echo '{"log":{"level":"info"}}' > /etc/sing-box/config.json
        }
    elif [ "$USE_CONVERTER" = "true" ]; then
        msg_info "转换 Clash 订阅..."
        python3 /opt/converter/convert.py "$SUB_URL" > /etc/sing-box/config.json || msg_error "转换失败"
    else
        msg_info "下载 sing-box 订阅..."
        curl -fsSL "$SUB_URL" -o /etc/sing-box/config.json || msg_error "下载失败"
    fi
    
    msg_ok "配置生成完成"
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
    echo "   sing-box 代理: http://${IP}:7890"
    
    if [ "$USE_SUBSTORE" = "true" ]; then
        echo "   Sub-Store 管理: http://${IP}:3001"
    fi
    
    echo ""
    echo "🔧 管理命令"
    echo "   systemctl status sing-box     # 状态"
    echo "   systemctl restart sing-box    # 重启"
    echo "   journalctl -u sing-box -f     # 日志"
    
    if [ "$USE_SUBSTORE" = "true" ]; then
        echo ""
        echo "🎛️  Sub-Store 管理"
        echo "   访问: http://${IP}:3001"
        echo "   systemctl status sub-store"
        echo "   journalctl -u sub-store -f"
    fi
    
    echo ""
    echo "🧪 测试代理"
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    header
    
    msg_info "步骤 1/8: 检查权限..."
    check_root
    
    msg_info "步骤 2/8: 检查系统..."
    check_system
    
    msg_info "步骤 3/8: 检测架构..."
    detect_arch
    
    msg_info "步骤 4/8: 选择模式..."
    choose_mode
    
    msg_info "步骤 5/8: 配置订阅..."
    get_subscription
    
    msg_info "步骤 6/8: 安装依赖..."
    install_deps
    
    if [ "$USE_SUBSTORE" = "true" ]; then
        install_nodejs
        install_substore
        setup_substore_service
    else
        create_converter
    fi
    
    msg_info "步骤 7/8: 安装 sing-box..."
    install_singbox
    download_geofiles
    setup_config
    
    msg_info "步骤 8/8: 配置服务..."
    setup_service
    
    show_summary
}

set -E
trap 'msg_error "安装失败，请查看上述输出"' ERR

main
