#!/usr/bin/env bash
# sing-box + Clash转换服务 一体化安装脚本
# 在 sing-box VM 上运行：bash install-singbox.sh
# 或在线运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash
# 调试模式：DEBUG=1 bash install-singbox.sh

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
    echo "  sing-box + Clash转换服务 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限，请使用: sudo bash install-singbox.sh"
    fi
    msg_info "Root 权限检查通过"
}

check_system() {
    msg_info "检查系统..."
    
    if [ ! -f /etc/os-release ]; then
        msg_error "无法检测系统类型，需要 /etc/os-release 文件"
    fi
    
    # 读取系统信息
    . /etc/os-release
    msg_info "检测到系统: $PRETTY_NAME"
    
    # 检查是否是 Debian 系列
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

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    
    msg_info "更新软件包列表..."
    if ! apt-get update -qq; then
        msg_error "apt-get update 失败，请检查网络连接和源配置"
    fi
    
    msg_info "安装系统依赖包..."
    if ! apt-get install -y -qq curl wget unzip gzip iptables jq python3 python3-pip 2>&1 | grep -v "^$"; then
        msg_warn "部分依赖包安装可能有警告，但继续执行..."
    fi
    
    msg_info "安装 Python 依赖..."
    if ! pip3 install --quiet pyyaml 2>/dev/null; then
        msg_warn "pip3 安装 pyyaml 失败，尝试备用方法..."
        apt-get install -y -qq python3-yaml
    fi
    
    msg_ok "依赖安装完成"
}

get_subscription() {
    echo ""
    
    # 如果环境变量已设置，直接使用
    if [ -n "$SUB_URL" ]; then
        msg_info "使用环境变量订阅地址: $SUB_URL"
    else
        # 从终端读取输入（支持管道运行）
        if [ -t 0 ]; then
            # 标准输入是终端
            read -p "订阅地址: " SUB_URL
        else
            # 标准输入被重定向，切换到 /dev/tty
            exec < /dev/tty
            read -p "订阅地址: " SUB_URL
        fi
    fi
    
    [ -z "$SUB_URL" ] && msg_error "订阅地址不能为空"
    [[ ! "$SUB_URL" =~ ^https?:// ]] && msg_error "订阅地址格式错误"
    msg_ok "订阅地址: $SUB_URL"
    
    echo ""
    
    # 订阅类型配置
    if [ -n "$SUB_TYPE" ]; then
        msg_info "使用环境变量订阅类型: $SUB_TYPE"
    else
        if [ -t 0 ]; then
            read -p "订阅格式 (1=sing-box, 2=Clash需转换) [1]: " SUB_TYPE
        else
            exec < /dev/tty
            read -p "订阅格式 (1=sing-box, 2=Clash需转换) [1]: " SUB_TYPE
        fi
    fi
    
    SUB_TYPE=${SUB_TYPE:-1}
    
    if [ "$SUB_TYPE" = "2" ]; then
        USE_CONVERTER=true
        msg_ok "将启用Clash转换"
    else
        USE_CONVERTER=false
        msg_ok "使用sing-box订阅"
    fi
}

install_singbox() {
    msg_info "安装 sing-box..."
    
    VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
    [ -z "$VERSION" ] && msg_error "获取版本失败"
    
    URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${ARCH}.tar.gz"
    wget -q --show-progress "$URL" -O /tmp/singbox.tar.gz || msg_error "下载失败"
    
    tar -xzf /tmp/singbox.tar.gz -C /tmp/
    install -m 755 /tmp/sing-box-${VERSION}-linux-${ARCH}/sing-box /usr/local/bin/sing-box
    rm -rf /tmp/singbox* /tmp/sing-box-*
    
    msg_ok "sing-box v${VERSION} 安装完成"
}

download_geofiles() {
    msg_info "下载 GEO 数据库..."
    mkdir -p /etc/sing-box
    curl -fsSL https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db -o /etc/sing-box/geoip.db
    curl -fsSL https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db -o /etc/sing-box/geosite.db
    msg_ok "GEO 数据库完成"
}

create_converter() {
    if [ "$USE_CONVERTER" != "true" ]; then
        return
    fi
    
    msg_info "部署 Clash 转换服务..."
    
    mkdir -p /opt/converter
    cat > /opt/converter/convert.py <<'EOF'
#!/usr/bin/env python3
import json, yaml, sys, urllib.request, base64

def convert(clash_yaml):
    # 尝试 base64 解码
    try:
        decoded = base64.b64decode(clash_yaml).decode('utf-8')
        clash_yaml = decoded
    except:
        pass
    
    # 解析 YAML
    try:
        c = yaml.safe_load(clash_yaml)
    except Exception as e:
        print(f"错误：YAML 解析失败 - {e}", file=sys.stderr)
        sys.exit(1)
    
    # 检查是否是字典
    if not isinstance(c, dict):
        print(f"错误：订阅格式不正确，期望 YAML 字典，得到 {type(c).__name__}", file=sys.stderr)
        print(f"订阅内容前100字符: {str(c)[:100]}", file=sys.stderr)
        sys.exit(1)
    
    # 检查是否有 proxies 字段
    if 'proxies' not in c or not c['proxies']:
        print("错误：订阅中没有找到节点（proxies字段为空或不存在）", file=sys.stderr)
        print(f"可用字段: {list(c.keys())}", file=sys.stderr)
        sys.exit(1)
    
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
    
    outbounds, tags = [], []
    for p in c.get('proxies', []):
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
        
        outbounds.append(o)
        tags.append(p['name'])
    
    outbounds = [
        {"type": "selector", "tag": "proxy", "outbounds": ["auto"] + tags + ["direct"], "default": "auto"},
        {"type": "urltest", "tag": "auto", "outbounds": tags, "url": "https://www.gstatic.com/generate_204", "interval": "10m"},
        {"type": "direct", "tag": "direct"},
        {"type": "block", "tag": "block"},
        {"type": "dns", "tag": "dns-out"}
    ] + outbounds
    
    sb['outbounds'] = outbounds
    return json.dumps(sb, indent=2)

if __name__ == '__main__':
    url = sys.argv[1] if len(sys.argv) > 1 else input("订阅URL: ")
    with urllib.request.urlopen(url) as r:
        print(convert(r.read().decode()))
EOF
    
    chmod +x /opt/converter/convert.py
    msg_ok "转换工具部署完成"
}

setup_config() {
    msg_info "生成配置..."
    
    mkdir -p /etc/sing-box
    
    if [ "$USE_CONVERTER" = "true" ]; then
        msg_info "转换 Clash 订阅..."
        python3 /opt/converter/convert.py "$SUB_URL" > /etc/sing-box/config.json || msg_error "转换失败"
    else
        msg_info "下载 sing-box 订阅..."
        curl -fsSL "$SUB_URL" -o /etc/sing-box/config.json || msg_error "下载失败"
    fi
    
    echo "$SUB_URL" > /etc/sing-box/.subscription
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
WorkingDirectory=/etc/sing-box
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    sleep 3
    
    systemctl is-active --quiet sing-box || msg_error "服务启动失败，查看: journalctl -u sing-box"
    msg_ok "服务启动成功"
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
    echo "   代理: http://${IP}:7890 (HTTP+SOCKS5)"
    echo ""
    echo "🔧 管理命令"
    echo "   systemctl status sing-box    # 状态"
    echo "   systemctl restart sing-box   # 重启"
    echo "   journalctl -u sing-box -f    # 日志"
    echo ""
    echo "🧪 测试"
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "📝 配置"
    echo "   /etc/sing-box/config.json"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    # 显示标题
    header
    
    # 步骤 1: 检查权限
    msg_info "步骤 1/9: 检查权限..."
    check_root
    
    # 步骤 2: 检查系统
    msg_info "步骤 2/9: 检查系统..."
    check_system
    
    # 步骤 3: 检测架构
    msg_info "步骤 3/9: 检测架构..."
    detect_arch
    
    # 步骤 4: 获取订阅
    msg_info "步骤 4/9: 配置订阅..."
    get_subscription
    
    # 步骤 5: 安装依赖
    msg_info "步骤 5/9: 安装依赖..."
    install_deps
    
    # 步骤 6: 安装 sing-box
    msg_info "步骤 6/9: 安装 sing-box..."
    install_singbox
    
    # 步骤 7: 下载地理数据库
    msg_info "步骤 7/9: 下载地理数据库..."
    download_geofiles
    
    # 步骤 8: 创建转换服务
    msg_info "步骤 8/9: 创建转换服务..."
    create_converter
    
    # 步骤 9: 配置服务
    msg_info "步骤 9/9: 配置服务..."
    setup_config
    setup_service
    
    # 完成
    show_summary
}

# 捕获错误
set -E
trap 'msg_error "安装过程中发生错误，请检查上述输出"' ERR

main

