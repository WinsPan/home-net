#!/usr/bin/env bash
# sing-box + Clash转换服务 一体化安装脚本
# 在 sing-box VM 上运行：bash install-singbox.sh
# 或在线运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash

set -e

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
    [ "$EUID" -ne 0 ] && msg_error "需要 root 权限"
}

check_system() {
    [ ! -f /etc/debian_version ] && msg_error "仅支持 Debian 系统"
    msg_ok "系统检查通过"
}

detect_arch() {
    case $(uname -m) in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) msg_error "不支持的架构: $(uname -m)" ;;
    esac
}

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget unzip gzip iptables jq python3 python3-pip &>/dev/null
    pip3 install --quiet pyyaml &>/dev/null
    msg_ok "依赖安装完成"
}

get_subscription() {
    echo ""
    read -p "订阅地址: " SUB_URL
    [ -z "$SUB_URL" ] && msg_error "订阅地址不能为空"
    [[ ! "$SUB_URL" =~ ^https?:// ]] && msg_error "订阅地址格式错误"
    
    echo ""
    read -p "订阅格式 (1=sing-box, 2=Clash需转换) [1]: " SUB_TYPE
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
import json, yaml, sys, urllib.request

def convert(clash_yaml):
    c = yaml.safe_load(clash_yaml)
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
    header
    check_root
    check_system
    detect_arch
    get_subscription
    install_deps
    install_singbox
    download_geofiles
    create_converter
    setup_config
    setup_service
    show_summary
}

main

