#!/bin/bash
# BoomDNS 在线安装脚本
# 使用方式: curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/WinsPan/home-net/main"
INSTALL_DIR="/opt/boomdns"

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
function msg_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

function show_banner() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║      BoomDNS 在线安装                ║
║   sing-box + AdGuard Home              ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行"
    fi
}

function check_proxmox() {
    if ! command -v qm &>/dev/null; then
        msg_error "需要在 Proxmox 节点运行"
    fi
    msg_ok "Proxmox 环境检测通过"
}

function install_deps() {
    msg_info "安装依赖..."
    apt-get update -qq
    apt-get install -y -qq curl wget &>/dev/null
    msg_ok "依赖安装完成"
}

function download_scripts() {
    msg_info "下载脚本到 ${INSTALL_DIR}..."
    
    # 创建目录
    mkdir -p ${INSTALL_DIR}/{vm,services/{sing-box,adguardhome},routeros,docs}
    
    # 下载主脚本
    curl -fsSL ${REPO}/setup.sh -o ${INSTALL_DIR}/setup.sh
    
    # 下载 VM 创建脚本
    curl -fsSL ${REPO}/vm/create-vm.sh -o ${INSTALL_DIR}/vm/create-vm.sh
    
    # 下载 sing-box 脚本
    curl -fsSL ${REPO}/services/sing-box/install.sh -o ${INSTALL_DIR}/services/sing-box/install.sh
    
    # 下载 AdGuard 脚本
    curl -fsSL ${REPO}/services/adguardhome/install.sh -o ${INSTALL_DIR}/services/adguardhome/install.sh
    
    # 下载 RouterOS 脚本
    curl -fsSL ${REPO}/routeros/generate-config.sh -o ${INSTALL_DIR}/routeros/generate-config.sh
    
    # 下载文档
    curl -fsSL ${REPO}/README.md -o ${INSTALL_DIR}/README.md 2>/dev/null || true
    curl -fsSL ${REPO}/docs/CONFIG.md -o ${INSTALL_DIR}/docs/CONFIG.md 2>/dev/null || true
    
    # 设置执行权限
    chmod +x ${INSTALL_DIR}/setup.sh
    chmod +x ${INSTALL_DIR}/vm/create-vm.sh
    chmod +x ${INSTALL_DIR}/services/sing-box/*.sh
    chmod +x ${INSTALL_DIR}/services/adguardhome/*.sh
    chmod +x ${INSTALL_DIR}/routeros/*.sh
    
    msg_ok "脚本下载完成"
}

function create_shortcuts() {
    msg_info "创建快捷命令..."
    
    # 创建全局命令
    cat > /usr/local/bin/boomdns << 'SHORTCUT'
#!/bin/bash
case "$1" in
    setup)
        bash /opt/boomdns/setup.sh
        ;;
    create-vm)
        bash /opt/boomdns/vm/create-vm.sh
        ;;
    routeros)
        bash /opt/boomdns/routeros/generate-config.sh
        ;;
    update)
        curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install.sh | bash
        ;;
    *)
        cat << EOF
╔══════════════════════════════════════════════════════════╗
║           BoomDNS 家庭网络解决方案                        ║
╚══════════════════════════════════════════════════════════╝

使用方式:
  boomdns <command>

命令列表:
  setup        查看部署指南（推荐）
  create-vm    创建 VM
  routeros     生成 RouterOS 配置
  update       更新脚本到最新版本

快速开始:
  boomdns setup

服务安装（在对应 VM 上运行）:
  # sing-box (在 10.0.0.3)
  curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/sing-box/install.sh | bash
  
  # AdGuard Home (在 10.0.0.4)
  curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash

更多帮助: cat /opt/boomdns/README.md
EOF
        ;;
esac
SHORTCUT
    
    chmod +x /usr/local/bin/boomdns
    msg_ok "快捷命令创建完成"
}

function show_summary() {
    echo ""
    echo "══════════════════════════════════════"
    msg_ok "安装完成！"
    echo "══════════════════════════════════════"
    echo ""
    echo "脚本位置: ${CYAN}${INSTALL_DIR}${NC}"
    echo ""
    echo "快速开始:"
    echo "  ${GREEN}boomdns setup${NC}          # 一键部署"
    echo ""
    echo "其他命令:"
    echo "  ${GREEN}boomdns sing-box${NC}         # 管理 sing-box"
    echo "  ${GREEN}boomdns create-vm${NC}      # 创建 VM"
    echo "  ${GREEN}boomdns adguard${NC}        # 安装 AdGuard"
    echo "  ${GREEN}boomdns routeros${NC}       # 生成 RouterOS 配置"
    echo "  ${GREEN}boomdns update${NC}         # 更新到最新版本"
    echo ""
    echo "查看帮助:"
    echo "  ${GREEN}boomdns${NC}               # 显示所有命令"
    echo "  ${GREEN}cat ${INSTALL_DIR}/README.md${NC}"
    echo ""
    echo "══════════════════════════════════════"
}

function main() {
    show_banner
    check_root
    check_proxmox
    install_deps
    download_scripts
    create_shortcuts
    show_summary
    
    # 询问是否立即运行
    echo ""
    read -p "是否立即开始部署？(y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec bash ${INSTALL_DIR}/setup.sh
    else
        echo ""
        msg_info "稍后可运行: ${GREEN}boomdns setup${NC}"
        echo ""
    fi
}

main

