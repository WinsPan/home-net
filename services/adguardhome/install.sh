#!/usr/bin/env bash
# AdGuard Home 独立安装脚本
# 在 AdGuard Home VM 上直接运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash

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
║         AdGuard Home - 网络级广告拦截 DNS                ║
║                                                          ║
║  支持：广告过滤 + 隐私保护 + DNS 管理                     ║
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
        x86_64) ARCH="linux_amd64" ;;
        aarch64) ARCH="linux_arm64" ;;
        *) msg_error "不支持的架构: $(uname -m)" ;;
    esac
    msg_info "系统架构: $ARCH"
}

function install_deps() {
    msg_info "安装依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget tar &>/dev/null
    msg_ok "依赖安装完成"
}

function free_port_53() {
    msg_info "释放 DNS 端口 (53)..."
    
    # 检查端口占用
    if ss -tulpn | grep -q ':53 '; then
        msg_warn "端口 53 被占用，准备释放..."
        
        # 停止并禁用 systemd-resolved
        if systemctl is-active --quiet systemd-resolved; then
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            msg_ok "已停止 systemd-resolved"
        fi
        
        # 配置备用 DNS
        rm -f /etc/resolv.conf
        cat > /etc/resolv.conf <<EOF
# AdGuard Home 临时 DNS 配置
nameserver 223.5.5.5
nameserver 8.8.8.8
EOF
        
        # 锁定文件防止被覆盖
        chattr +i /etc/resolv.conf
        
        msg_ok "端口 53 已释放"
    else
        msg_ok "端口 53 可用"
    fi
}

function install_adguard() {
    msg_info "下载 AdGuard Home..."
    
    URL="https://static.adguard.com/adguardhome/release/AdGuardHome_${ARCH}.tar.gz"
    
    if ! wget -q --show-progress "$URL" -O /tmp/adguardhome.tar.gz 2>&1; then
        msg_error "下载失败"
    fi
    
    if [ ! -s /tmp/adguardhome.tar.gz ]; then
        msg_error "下载的文件无效"
    fi
    
    msg_info "解压安装..."
    tar -xzf /tmp/adguardhome.tar.gz -C /opt/ || msg_error "解压失败"
    rm -f /tmp/adguardhome.tar.gz
    
    msg_ok "AdGuard Home 安装完成"
}

function setup_service() {
    msg_info "配置 systemd 服务..."
    
    if ! /opt/AdGuardHome/AdGuardHome -s install &>/dev/null; then
        msg_error "服务安装失败（端口可能被占用）"
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "AdGuard Home 安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 Web 管理界面："
    echo "   http://${IP}:3000"
    echo ""
    echo "🔧 初始化步骤："
    echo "   1. 访问: http://${IP}:3000"
    echo "   2. 设置管理员账号密码"
    echo "   3. 配置 DNS 监听端口: 53 (默认)"
    echo "   4. 配置 Web 管理端口: 3000 (默认)"
    echo ""
    echo "🌐 推荐上游 DNS："
    echo "   https://dns.alidns.com/dns-query"
    echo "   https://doh.pub/dns-query"
    echo "   223.5.5.5"
    echo ""
    echo "🛡️ 推荐过滤规则："
    echo "   https://anti-ad.net/easylist.txt"
    echo "   AdGuard DNS filter (内置)"
    echo "   EasyList China (内置)"
    echo ""
    echo "📋 管理命令："
    echo "   查看状态: systemctl status AdGuardHome"
    echo "   重启服务: systemctl restart AdGuardHome"
    echo "   查看日志: journalctl -u AdGuardHome -f"
    echo "   停止服务: systemctl stop AdGuardHome"
    echo ""
    echo "💡 下一步："
    echo "   1. 完成 Web 界面初始化"
    echo "   2. 添加过滤规则"
    echo "   3. 配置 RouterOS DHCP DNS: ${IP}"
    echo "   4. 客户端将自动使用 AdGuard Home 过滤广告"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function main() {
    header
    check_system
    detect_arch
    install_deps
    free_port_53
    install_adguard
    setup_service
    show_summary
}

main
