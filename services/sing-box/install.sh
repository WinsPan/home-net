#!/usr/bin/env bash
# sing-box 独立安装脚本
# 在 sing-box VM 上直接运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/sing-box/install.sh | bash

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
║          sing-box 通用代理平台 - 快速安装                ║
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
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) msg_error "不支持的架构: $(uname -m)" ;;
    esac
    msg_info "系统架构: $ARCH"
}

function install_deps() {
    msg_info "安装依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget unzip gzip iptables jq &>/dev/null
    msg_ok "依赖安装完成"
}

function get_subscription() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_info "请输入订阅信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 优先使用环境变量（支持自动化安装）
    if [ -z "$SUBSCRIPTION_URL" ]; then
        read -p "订阅地址（Clash 或 sing-box 格式）: " SUBSCRIPTION_URL
        while [ -z "$SUBSCRIPTION_URL" ]; do
            msg_error "订阅地址不能为空"
            read -p "订阅地址: " SUBSCRIPTION_URL
        done
    fi
    
    if [[ ! "$SUBSCRIPTION_URL" =~ ^https?:// ]]; then
        msg_error "订阅地址格式错误（需要 http:// 或 https://）: $SUBSCRIPTION_URL"
    fi
    
    # 询问是否需要转换
    if [ -z "$USE_CONVERTER" ]; then
        echo ""
        read -p "订阅是 Clash 格式吗？需要转换吗？(y/n) [n]: " USE_CONVERTER
        USE_CONVERTER=${USE_CONVERTER:-n}
    fi
    
    echo ""
    msg_ok "订阅地址: $SUBSCRIPTION_URL"
    if [[ "$USE_CONVERTER" =~ ^[Yy]$ ]]; then
        msg_ok "将使用转换服务转换 Clash 订阅"
    fi
    echo ""
}

function install_singbox() {
    msg_info "安装 sing-box..."
    
    # 获取最新版本
    VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
    if [ -z "$VERSION" ]; then
        msg_error "获取最新版本失败"
    fi
    msg_ok "最新版本: v${VERSION}"
    
    # 下载
    URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${ARCH}.tar.gz"
    msg_info "下载 sing-box..."
    
    if ! wget -q --show-progress "$URL" -O /tmp/sing-box.tar.gz 2>&1; then
        msg_error "下载失败"
    fi
    
    if [ ! -s /tmp/sing-box.tar.gz ]; then
        msg_error "下载的文件无效"
    fi
    
    # 解压安装
    tar -xzf /tmp/sing-box.tar.gz -C /tmp/ || msg_error "解压失败"
    install -m 755 /tmp/sing-box-${VERSION}-linux-${ARCH}/sing-box /usr/local/bin/sing-box || msg_error "安装失败"
    rm -rf /tmp/sing-box*
    
    msg_ok "sing-box 安装完成 (v${VERSION})"
}

function download_subscription() {
    msg_info "下载订阅..."
    
    mkdir -p /etc/sing-box
    
    # 如果需要转换
    if [[ "$USE_CONVERTER" =~ ^[Yy]$ ]]; then
        msg_info "使用转换服务..."
        # 使用本地转换服务（假设在同一台机器或指定的转换服务器）
        local CONVERTER_URL="http://127.0.0.1:8080/convert?url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SUBSCRIPTION_URL'))")"
        
        if ! curl -fsSL "$CONVERTER_URL" -o /etc/sing-box/config.json; then
            msg_warn "转换服务不可用，将使用默认配置"
            SUBSCRIPTION_URL=""
        else
            msg_ok "订阅转换成功"
        fi
    else
        # 直接下载 sing-box 订阅
        if ! curl -fsSL "$SUBSCRIPTION_URL" -o /etc/sing-box/config.json; then
            msg_warn "订阅下载失败，将使用默认配置"
            SUBSCRIPTION_URL=""
        else
            msg_ok "订阅下载成功"
        fi
    fi
}

function setup_config() {
    msg_info "生成配置文件..."
    
    # 如果没有订阅或下载失败，使用默认配置
    if [ -z "$SUBSCRIPTION_URL" ] || [ ! -f /etc/sing-box/config.json ]; then
        cat > /etc/sing-box/config.json <<'EOF'
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns_proxy",
        "address": "https://1.1.1.1/dns-query",
        "detour": "proxy"
      },
      {
        "tag": "dns_direct",
        "address": "https://223.5.5.5/dns-query",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "geosite": "cn",
        "server": "dns_direct"
      }
    ],
    "final": "dns_proxy"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "0.0.0.0",
      "listen_port": 7890,
      "sniff": true
    },
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "inet4_address": "172.19.0.1/30",
      "auto_route": false,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["auto", "direct"],
      "default": "auto"
    },
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": [],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "10m",
      "tolerance": 50
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geosite": "cn",
        "geoip": ["cn", "private"],
        "outbound": "direct"
      },
      {
        "geosite": "category-ads-all",
        "outbound": "block"
      }
    ],
    "final": "proxy",
    "auto_detect_interface": true
  }
}
EOF
    fi
    
    # 保存订阅地址
    if [ -n "$SUBSCRIPTION_URL" ]; then
        echo "$SUBSCRIPTION_URL" > /etc/sing-box/.subscription
    fi
    
    msg_ok "配置文件生成完成"
}

function download_geofiles() {
    msg_info "下载 GEO 数据库..."
    
    mkdir -p /etc/sing-box
    
    # 下载 geoip
    curl -fsSL https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db -o /etc/sing-box/geoip.db
    
    # 下载 geosite
    curl -fsSL https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db -o /etc/sing-box/geosite.db
    
    msg_ok "GEO 数据库下载完成"
}

function setup_service() {
    msg_info "配置 systemd 服务..."
    
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/sing-box
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    
    sleep 3
    
    if systemctl is-active --quiet sing-box; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败，查看日志: journalctl -u sing-box -n 50"
    fi
}

function show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "sing-box 安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 服务信息："
    echo "   IP 地址: ${IP}"
    echo "   Mixed 代理: http://${IP}:7890 (HTTP/SOCKS5)"
    echo ""
    echo "🔧 管理命令："
    echo "   查看状态: systemctl status sing-box"
    echo "   重启服务: systemctl restart sing-box"
    echo "   查看日志: journalctl -u sing-box -f"
    echo "   停止服务: systemctl stop sing-box"
    echo ""
    echo "🧪 测试代理："
    echo "   curl -x http://${IP}:7890 https://www.google.com -I"
    echo ""
    echo "📝 配置文件："
    echo "   /etc/sing-box/config.json"
    echo ""
    echo "🔄 更新订阅："
    echo "   systemctl restart sing-box"
    echo ""
    echo "💡 下一步："
    echo "   1. 在客户端设置代理: http://${IP}:7890"
    echo "   2. 或配置 RouterOS 透明代理"
    if [[ "$USE_CONVERTER" =~ ^[Yy]$ ]]; then
        echo "   3. 确保转换服务正常运行"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function main() {
    header
    check_system
    detect_arch
    get_subscription
    install_deps
    install_singbox
    download_geofiles
    download_subscription
    setup_config
    setup_service
    show_summary
}

main

