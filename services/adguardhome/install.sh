#!/usr/bin/env bash
# AdGuard Home 快速部署脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║   AdGuard Home 快速部署              ║
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
    
    URL="https://static.adguard.com/adguardhome/release/AdGuardHome_${ARCH}.tar.gz"
    msg_info "下载中..."
    
    if ! wget -q --show-progress "$URL" -O /tmp/adguardhome.tar.gz 2>&1; then
        msg_error "下载失败"
    fi
    
    if [ ! -s /tmp/adguardhome.tar.gz ]; then
        msg_error "下载的文件无效"
    fi
    
    tar -xzf /tmp/adguardhome.tar.gz -C /opt/ || msg_error "解压失败"
    rm -f /tmp/adguardhome.tar.gz
    
    msg_ok "AdGuard Home 安装完成"
}

function setup_service() {
    msg_info "配置服务..."
    
    if ! /opt/AdGuardHome/AdGuardHome -s install &>/dev/null; then
        msg_error "服务安装失败（可能端口 53 被占用）"
    fi
    
    systemctl enable AdGuardHome
    systemctl start AdGuardHome
    
    sleep 3
    
    if systemctl is-active --quiet AdGuardHome; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败，查看日志: journalctl -u AdGuardHome -n 50"
    fi
}

function show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "════════════════════════════════════════"
    msg_ok "AdGuard Home 安装完成！"
    echo "════════════════════════════════════════"
    echo ""
    echo "Web 界面: http://${IP}:3000"
    echo ""
    echo "初始化步骤:"
    echo "  1. 访问: http://${IP}:3000"
    echo "  2. 设置管理员账号密码"
    echo "  3. DNS 监听端口: 53 (默认)"
    echo ""
    echo "推荐 DNS 设置:"
    echo "  上游 DNS:"
    echo "    - https://dns.alidns.com/dns-query"
    echo "    - https://doh.pub/dns-query"
    echo "    - 223.5.5.5"
    echo ""
    echo "推荐过滤规则:"
    echo "  - https://anti-ad.net/easylist.txt"
    echo "  - AdGuard DNS filter"
    echo "  - EasyList China"
    echo ""
    echo "管理命令:"
    echo "  状态: systemctl status AdGuardHome"
    echo "  重启: systemctl restart AdGuardHome"
    echo "  日志: journalctl -u AdGuardHome -f"
    echo ""
    echo "下一步:"
    echo "  1. 完成 Web 界面初始化"
    echo "  2. 添加过滤规则"
    echo "  3. 配置 RouterOS 使用此 DNS 服务器"
    echo ""
}

function main() {
    header
    check_system
    detect_arch
    install_deps
    install_adguard
    setup_service
    show_summary
}

main

