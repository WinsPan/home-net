#!/usr/bin/env bash
# AdGuard Home 安装脚本

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
║   AdGuard Home 安装脚本              ║
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
        x86_64) ARCH="linux_amd64" ;;
        aarch64) ARCH="linux_arm64" ;;
        *) msg_error "不支持的架构" ;;
    esac
}

function install_deps() {
    msg_info "安装依赖..."
    apt-get update -qq
    apt-get install -y -qq curl wget tar &>/dev/null
    msg_ok "依赖安装完成"
}

function install_adguard() {
    msg_info "安装 AdGuard Home..."
    
    # 下载
    URL="https://static.adguard.com/adguardhome/release/AdGuardHome_${ARCH}.tar.gz"
    wget -q --show-progress "$URL" -O /tmp/adguardhome.tar.gz
    
    # 安装
    tar -xzf /tmp/adguardhome.tar.gz -C /opt/
    rm -f /tmp/adguardhome.tar.gz
    
    msg_ok "AdGuard Home 安装完成"
}

function setup_service() {
    msg_info "配置服务..."
    
    # 安装服务
    /opt/AdGuardHome/AdGuardHome -s install
    
    # 启动
    systemctl enable AdGuardHome
    systemctl start AdGuardHome
    
    msg_ok "服务启动完成"
}

function setup_rules() {
    msg_info "配置过滤规则..."
    
    # 等待服务启动
    sleep 5
    
    # 注意：规则需要在 Web 界面手动配置
    msg_ok "请在 Web 界面配置过滤规则"
}

function show_summary() {
    echo ""
    echo "══════════════════════════════════════"
    msg_ok "AdGuard Home 安装完成！"
    echo "══════════════════════════════════════"
    echo ""
    echo "Web 界面: http://10.0.0.4:3000"
    echo ""
    echo "初始化步骤:"
    echo "  1. 访问: http://10.0.0.4:3000"
    echo "  2. 设置管理员账号密码"
    echo "  3. DNS 监听端口: 53 (默认)"
    echo ""
    echo "推荐 DNS 设置:"
    echo "  上游 DNS:"
    echo "    - https://dns.alidns.com/dns-query"
    echo "    - https://doh.pub/dns-query"
    echo ""
    echo "  过滤规则:"
    echo "    - https://anti-ad.net/easylist.txt"
    echo ""
    echo "管理:"
    echo "  状态: systemctl status AdGuardHome"
    echo "  日志: journalctl -u AdGuardHome -f"
    echo ""
}

function main() {
    show_header
    check_system
    detect_arch
    install_deps
    install_adguard
    setup_service
    setup_rules
    show_summary
}

main
