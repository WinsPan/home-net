#!/usr/bin/env bash
# BoomDNS 主部署脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
function msg_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           BoomDNS 智能部署系统                           ║
║                                                          ║
║   mihomo + AdGuard Home + RouterOS                      ║
║   智能分流 + 广告过滤 + 完整管理                          ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        msg_error "需要 root 权限运行此脚本"
        exit 1
    fi
}

function check_proxmox() {
    if ! command -v qm &>/dev/null; then
        msg_error "未检测到 Proxmox 环境"
        msg_info "此脚本需要在 Proxmox 节点上运行"
        exit 1
    fi
    msg_ok "Proxmox 环境检测通过"
}

function show_main_menu() {
    header
    
    echo "【主菜单】"
    echo ""
    echo "  VM 管理:"
    echo "    1) 创建 mihomo VM"
    echo "    2) 创建 AdGuard Home VM"
    echo ""
    echo "  服务管理:"
    echo "    3) 安装 mihomo"
    echo "    4) 管理 mihomo (订阅/配置/透明代理)"
    echo "    5) 安装 AdGuard Home"
    echo ""
    echo "  RouterOS:"
    echo "    6) 生成 RouterOS 配置"
    echo ""
    echo "  快速部署:"
    echo "    7) 一键完整部署（推荐）"
    echo ""
    echo "  其他:"
    echo "    8) 查看文档"
    echo "    0) 退出"
    echo ""
    
    read -p "请选择: " choice
    
    case $choice in
        1) create_mihomo_vm ;;
        2) create_adguard_vm ;;
        3) install_mihomo ;;
        4) manage_mihomo ;;
        5) install_adguard ;;
        6) generate_routeros ;;
        7) full_deployment ;;
        8) show_docs ;;
        0) 
            msg_ok "退出"
            exit 0
            ;;
        *)
            msg_error "无效选项"
            sleep 1
            show_main_menu
            ;;
    esac
}

function create_mihomo_vm() {
    msg_step "创建 mihomo VM"
    echo ""
    
    if [ -f "$SCRIPT_DIR/vm/create-vm.sh" ]; then
        bash "$SCRIPT_DIR/vm/create-vm.sh"
    else
        msg_error "找不到 VM 创建脚本"
    fi
    
    echo ""
    read -p "按回车返回主菜单..."
    show_main_menu
}

function create_adguard_vm() {
    msg_step "创建 AdGuard Home VM"
    echo ""
    
    if [ -f "$SCRIPT_DIR/vm/create-vm.sh" ]; then
        bash "$SCRIPT_DIR/vm/create-vm.sh"
    else
        msg_error "找不到 VM 创建脚本"
    fi
    
    echo ""
    read -p "按回车返回主菜单..."
    show_main_menu
}

function install_mihomo() {
    msg_step "安装 mihomo"
    echo ""
    
    read -p "mihomo VM IP 地址: " MIHOMO_IP
    
    if [ -z "$MIHOMO_IP" ]; then
        msg_error "IP 地址不能为空"
        sleep 1
        show_main_menu
        return
    fi
    
    msg_info "连接到 $MIHOMO_IP..."
    
    if [ -f "$SCRIPT_DIR/services/mihomo/install.sh" ]; then
        scp "$SCRIPT_DIR/services/mihomo/install.sh" root@${MIHOMO_IP}:/tmp/ || {
            msg_error "无法连接到 VM，请检查 IP 和网络"
            sleep 2
            show_main_menu
            return
        }
        ssh root@${MIHOMO_IP} "bash /tmp/install.sh" || {
            msg_error "安装失败"
            sleep 2
        }
    else
        msg_error "找不到 mihomo 安装脚本"
    fi
    
    echo ""
    read -p "按回车返回主菜单..."
    show_main_menu
}

function manage_mihomo() {
    msg_step "管理 mihomo"
    echo ""
    
    read -p "mihomo VM IP 地址: " MIHOMO_IP
    
    if [ -z "$MIHOMO_IP" ]; then
        msg_error "IP 地址不能为空"
        sleep 1
        show_main_menu
        return
    fi
    
    if [ -f "$SCRIPT_DIR/services/mihomo/manage.sh" ]; then
        ssh -t root@${MIHOMO_IP} "bash -c \"\$(cat)\"" < "$SCRIPT_DIR/services/mihomo/manage.sh" || {
            msg_error "无法连接到 VM"
            sleep 2
        }
    else
        msg_error "找不到 mihomo 管理脚本"
    fi
    
    show_main_menu
}

function install_adguard() {
    msg_step "安装 AdGuard Home"
    echo ""
    
    read -p "AdGuard Home VM IP 地址: " ADGUARD_IP
    
    if [ -z "$ADGUARD_IP" ]; then
        msg_error "IP 地址不能为空"
        sleep 1
        show_main_menu
        return
    fi
    
    msg_info "连接到 $ADGUARD_IP..."
    
    if [ -f "$SCRIPT_DIR/services/adguardhome/install.sh" ]; then
        scp "$SCRIPT_DIR/services/adguardhome/install.sh" root@${ADGUARD_IP}:/tmp/ || {
            msg_error "无法连接到 VM"
            sleep 2
            show_main_menu
            return
        }
        ssh root@${ADGUARD_IP} "bash /tmp/install.sh" || {
            msg_error "安装失败"
            sleep 2
        }
    else
        msg_error "找不到 AdGuard Home 安装脚本"
    fi
    
    echo ""
    read -p "按回车返回主菜单..."
    show_main_menu
}

function generate_routeros() {
    msg_step "生成 RouterOS 配置"
    echo ""
    
    if [ -f "$SCRIPT_DIR/routeros/generate-config.sh" ]; then
        bash "$SCRIPT_DIR/routeros/generate-config.sh"
    else
        msg_error "找不到 RouterOS 配置生成脚本"
    fi
    
    echo ""
    read -p "按回车返回主菜单..."
    show_main_menu
}

function full_deployment() {
    header
    
    msg_warn "一键完整部署将执行以下操作："
    echo ""
    echo "  1. 创建 mihomo VM"
    echo "  2. 创建 AdGuard Home VM"
    echo "  3. 安装 mihomo 服务"
    echo "  4. 安装 AdGuard Home 服务"
    echo "  5. 生成 RouterOS 配置"
    echo ""
    echo "预计时间: 15-20 分钟"
    echo ""
    
    read -p "确认开始？(y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        show_main_menu
        return
    fi
    
    # 保存配置信息
    echo ""
    msg_info "收集配置信息..."
    echo ""
    
    read -p "mihomo IP [10.0.0.3]: " MIHOMO_IP
    MIHOMO_IP=${MIHOMO_IP:-10.0.0.3}
    
    read -p "AdGuard IP [10.0.0.4]: " ADGUARD_IP
    ADGUARD_IP=${ADGUARD_IP:-10.0.0.4}
    
    read -p "网关 [10.0.0.2]: " GATEWAY
    GATEWAY=${GATEWAY:-10.0.0.2}
    
    msg_ok "配置信息已收集"
    
    # 执行部署...
    msg_warn "请按照提示完成各步骤的配置"
    echo ""
    
    read -p "按回车开始部署..."
    
    msg_step "步骤 1/5: 创建 mihomo VM"
    create_mihomo_vm
    
    msg_step "步骤 2/5: 创建 AdGuard Home VM"
    create_adguard_vm
    
    msg_step "步骤 3/5: 安装 mihomo"
    install_mihomo
    
    msg_step "步骤 4/5: 安装 AdGuard Home"
    install_adguard
    
    msg_step "步骤 5/5: 生成 RouterOS 配置"
    generate_routeros
    
    echo ""
    echo "════════════════════════════════════════"
    msg_ok "完整部署完成！"
    echo "════════════════════════════════════════"
    echo ""
    echo "下一步："
    echo "  1. 在 AdGuard Home Web 界面完成初始化"
    echo "  2. 在 RouterOS 中应用生成的配置"
    echo "  3. 测试网络连接和广告过滤"
    echo ""
    
    read -p "按回车返回主菜单..."
    show_main_menu
}

function show_docs() {
    header
    
    echo "【文档】"
    echo ""
    
    if [ -f "$SCRIPT_DIR/docs/CONFIG.md" ]; then
        less "$SCRIPT_DIR/docs/CONFIG.md"
    else
        msg_warn "文档文件不存在"
    fi
    
    show_main_menu
}

function main() {
    check_root
    check_proxmox
    show_main_menu
}

main

