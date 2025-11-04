#!/usr/bin/env bash
# AdGuard Home 安装脚本
# 在 AdGuard Home VM 上运行：bash install-adguardhome.sh
# 或在线运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

header() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  AdGuard Home 安装程序"
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
        x86_64) ARCH="linux_amd64" ;;
        aarch64) ARCH="linux_arm64" ;;
        *) msg_error "不支持的架构: $(uname -m)" ;;
    esac
}

install_deps() {
    msg_info "安装依赖..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget tar &>/dev/null
    msg_ok "依赖完成"
}

free_port_53() {
    msg_info "释放端口 53..."
    
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
    fi
    
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf <<EOF
nameserver 223.5.5.5
nameserver 8.8.8.8
EOF
    chattr +i /etc/resolv.conf
    
    msg_ok "端口 53 已释放"
}

install_adguard() {
    msg_info "下载 AdGuard Home..."
    
    URL="https://static.adguard.com/adguardhome/release/AdGuardHome_${ARCH}.tar.gz"
    wget -q --show-progress "$URL" -O /tmp/agh.tar.gz || msg_error "下载失败"
    
    tar -xzf /tmp/agh.tar.gz -C /opt/
    rm -f /tmp/agh.tar.gz
    
    msg_ok "AdGuard Home 安装完成"
}

setup_service() {
    msg_info "配置服务..."
    
    /opt/AdGuardHome/AdGuardHome -s install &>/dev/null || msg_error "服务安装失败"
    systemctl enable AdGuardHome
    systemctl start AdGuardHome
    sleep 3
    
    systemctl is-active --quiet AdGuardHome || msg_error "服务启动失败，查看: journalctl -u AdGuardHome"
    msg_ok "服务启动成功"
}

show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 Web 管理"
    echo "   http://${IP}:3000"
    echo ""
    echo "🔧 管理命令"
    echo "   systemctl status AdGuardHome    # 状态"
    echo "   systemctl restart AdGuardHome   # 重启"
    echo "   journalctl -u AdGuardHome -f    # 日志"
    echo ""
    echo "⚙️  初始化"
    echo "   1. 访问 http://${IP}:3000"
    echo "   2. 设置管理员账号密码"
    echo "   3. DNS端口: 53 (默认)"
    echo ""
    echo "🌐 推荐上游DNS"
    echo "   https://dns.alidns.com/dns-query"
    echo "   https://doh.pub/dns-query"
    echo ""
    echo "🛡️  推荐规则"
    echo "   https://anti-ad.net/easylist.txt"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    header
    check_root
    check_system
    detect_arch
    install_deps
    free_port_53
    install_adguard
    setup_service
    show_summary
}

main

