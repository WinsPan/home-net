#!/usr/bin/env bash
# AdGuard Home 安装脚本
# 在 AdGuard Home VM 上运行：bash install-adguardhome.sh
# 或在线运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh | bash

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
    echo "  AdGuard Home 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限，请使用: sudo bash install-adguardhome.sh"
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
        x86_64) ARCH="linux_amd64" ;;
        aarch64) ARCH="linux_arm64" ;;
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
    if ! apt-get install -y -qq curl wget tar 2>&1 | grep -v "^$"; then
        msg_warn "部分依赖包安装可能有警告，但继续执行..."
    fi
    
    msg_ok "依赖安装完成"
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
    # 显示标题
    header
    
    # 步骤 1: 检查权限
    msg_info "步骤 1/7: 检查权限..."
    check_root
    
    # 步骤 2: 检查系统
    msg_info "步骤 2/7: 检查系统..."
    check_system
    
    # 步骤 3: 检测架构
    msg_info "步骤 3/7: 检测架构..."
    detect_arch
    
    # 步骤 4: 安装依赖
    msg_info "步骤 4/7: 安装依赖..."
    install_deps
    
    # 步骤 5: 释放端口 53
    msg_info "步骤 5/7: 释放端口 53..."
    free_port_53
    
    # 步骤 6: 安装 AdGuard Home
    msg_info "步骤 6/7: 安装 AdGuard Home..."
    install_adguard
    
    # 步骤 7: 配置服务
    msg_info "步骤 7/7: 配置服务..."
    setup_service
    
    # 完成
    show_summary
}

# 捕获错误
set -E
trap 'msg_error "安装过程中发生错误，请检查上述输出"' ERR

main

