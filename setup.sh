#!/usr/bin/env bash
# BoomDNS 部署引导脚本
# 在 Proxmox 节点运行

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
function msg_step() { echo -e "${CYAN}[步骤]${NC} $1"; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           BoomDNS 家庭网络解决方案                        ║
║                                                          ║
║   mihomo (代理分流) + AdGuard Home (广告过滤)             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        msg_error "需要 root 权限运行"
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

function show_guide() {
    header
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📚 部署指南"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🎯 部署流程（3步）："
    echo ""
    echo "  第一步：在 PVE 节点创建 VM"
    echo "  第二步：在 mihomo VM 安装服务"
    echo "  第三步：在 AdGuard Home VM 安装服务"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    msg_step "第一步：创建 VM（在当前 PVE 节点执行）"
    echo ""
    echo "  1️⃣  创建 mihomo VM："
    echo "      bash vm/create-vm.sh"
    echo ""
    echo "      配置建议："
    echo "        VM 名称: mihomo"
    echo "        VMID: 101"
    echo "        CPU: 2 核"
    echo "        内存: 2048 MB"
    echo "        磁盘: 10 GB"
    echo "        IP: 10.0.0.3/24"
    echo "        网关: 10.0.0.2"
    echo ""
    echo "  2️⃣  创建 AdGuard Home VM："
    echo "      bash vm/create-vm.sh"
    echo ""
    echo "      配置建议："
    echo "        VM 名称: adguardhome"
    echo "        VMID: 102"
    echo "        CPU: 2 核"
    echo "        内存: 2048 MB"
    echo "        磁盘: 10 GB"
    echo "        IP: 10.0.0.4/24"
    echo "        网关: 10.0.0.2"
    echo ""
    
    msg_step "第二步：安装 mihomo（SSH 登录 mihomo VM 执行）"
    echo ""
    echo "  SSH 登录 mihomo VM："
    echo "      ssh root@10.0.0.3"
    echo ""
    echo "  在 mihomo VM 上运行安装脚本："
    echo "      curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/mihomo/install.sh | bash"
    echo ""
    echo "  或者使用本地脚本："
    echo "      scp services/mihomo/install.sh root@10.0.0.3:/tmp/"
    echo "      ssh root@10.0.0.3 'bash /tmp/install.sh'"
    echo ""
    echo "  根据提示输入机场订阅地址"
    echo ""
    
    msg_step "第三步：安装 AdGuard Home（SSH 登录 AdGuard Home VM 执行）"
    echo ""
    echo "  SSH 登录 AdGuard Home VM："
    echo "      ssh root@10.0.0.4"
    echo ""
    echo "  在 AdGuard Home VM 上运行安装脚本："
    echo "      curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash"
    echo ""
    echo "  或者使用本地脚本："
    echo "      scp services/adguardhome/install.sh root@10.0.0.4:/tmp/"
    echo "      ssh root@10.0.0.4 'bash /tmp/install.sh'"
    echo ""
    echo "  安装完成后访问: http://10.0.0.4:3000 初始化"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    msg_info "💡 提示："
    echo "   • VM 创建后会自动启动并配置好网络"
    echo "   • 密码登录无需配置 SSH 密钥"
    echo "   • 每个服务独立安装互不影响"
    echo ""
    
    read -p "按回车键继续查看快速命令..."
    show_quick_commands
}

function show_quick_commands() {
    clear
    header
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚡ 快速部署命令"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "📦 第一步：创建 VM"
    echo ""
    echo "# 创建 mihomo VM"
    echo "bash vm/create-vm.sh"
    echo ""
    echo "# 创建 AdGuard Home VM"
    echo "bash vm/create-vm.sh"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🚀 第二步：安装 mihomo"
    echo ""
    echo "# 方式 1：在线安装（推荐）"
    echo "ssh root@10.0.0.3 'curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/mihomo/install.sh | bash'"
    echo ""
    echo "# 方式 2：本地脚本"
    echo "scp services/mihomo/install.sh root@10.0.0.3:/tmp/ && ssh root@10.0.0.3 'bash /tmp/install.sh'"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🛡️  第三步：安装 AdGuard Home"
    echo ""
    echo "# 方式 1：在线安装（推荐）"
    echo "ssh root@10.0.0.4 'curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash'"
    echo ""
    echo "# 方式 2：本地脚本"
    echo "scp services/adguardhome/install.sh root@10.0.0.4:/tmp/ && ssh root@10.0.0.4 'bash /tmp/install.sh'"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🌐 第四步：配置 RouterOS（可选）"
    echo ""
    echo "bash routeros/generate-config.sh"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "📋 服务访问地址："
    echo ""
    echo "  mihomo 管理面板: http://10.0.0.3:9090"
    echo "  AdGuard Home:    http://10.0.0.4:3000"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function show_menu() {
    while true; do
        clear
        header
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🎯 选择操作"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  1) 📚 查看部署指南（推荐）"
        echo "  2) 📦 创建 VM"
        echo "  3) ⚡ 查看快速命令"
        echo "  4) 🌐 生成 RouterOS 配置"
        echo "  0) 🚪 退出"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        read -p "请选择 [0-4]: " choice
        
        case $choice in
            1)
                show_guide
                ;;
            2)
                if [ -f "$SCRIPT_DIR/vm/create-vm.sh" ]; then
                    bash "$SCRIPT_DIR/vm/create-vm.sh"
                else
                    msg_error "找不到 VM 创建脚本"
                fi
                read -p "按回车返回主菜单..."
                ;;
            3)
                show_quick_commands
                read -p "按回车返回主菜单..."
                ;;
            4)
                if [ -f "$SCRIPT_DIR/routeros/generate-config.sh" ]; then
                    bash "$SCRIPT_DIR/routeros/generate-config.sh"
                else
                    msg_error "找不到 RouterOS 配置生成脚本"
                fi
                read -p "按回车返回主菜单..."
                ;;
            0)
                msg_ok "再见！"
                exit 0
                ;;
            *)
                msg_error "无效选择"
                sleep 1
                ;;
        esac
    done
}

function main() {
    check_root
    check_proxmox
    show_menu
}

main
