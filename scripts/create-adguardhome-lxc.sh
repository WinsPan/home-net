#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# 在 Proxmox VE 上自动创建 Debian LXC 容器并安装 AdGuard Home

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

function msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║      _       _  ____                       _         ║
║     / \   __| |/ ___|_   _  __ _ _ __ __| |        ║
║    / _ \ / _` | |  _| | | |/ _` | '__/ _` |        ║
║   / ___ \ (_| | |_| | |_| | (_| | | | (_| |        ║
║  /_/   \_\__,_|\____|\__,_|\__,_|_|  \__,_|        ║
║                                                      ║
║      AdGuard Home LXC 容器自动部署脚本               ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_proxmox() {
    if ! command -v pct &> /dev/null; then
        msg_error "此脚本必须在 Proxmox VE 主机上运行!"
        exit 1
    fi
    msg_ok "Proxmox VE 环境检测通过"
}

function get_next_id() {
    CTID=$(pvesh get /cluster/nextid)
    msg_info "建议的容器 ID: $CTID"
    read -p "请输入容器 ID (直接回车使用 $CTID): " USER_CTID
    if [ -n "$USER_CTID" ]; then
        CTID=$USER_CTID
    fi
}

function configure_container() {
    msg_info "配置容器参数..."
    
    read -p "请输入容器名称 (默认: adguardhome): " CT_NAME
    CT_NAME=${CT_NAME:-adguardhome}
    
    pvesm status | awk 'NR>1 {print $1}' | grep -v "^Type$"
    read -p "请选择存储位置 (默认: local-lvm): " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    read -p "请输入磁盘大小 (GB, 默认: 4): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-4}
    
    read -p "请输入 CPU 核心数 (默认: 2): " CORES
    CORES=${CORES:-2}
    
    read -p "请输入内存大小 (MB, 默认: 512): " MEMORY
    MEMORY=${MEMORY:-512}
    
    read -p "请输入网络桥接 (默认: vmbr0): " BRIDGE
    BRIDGE=${BRIDGE:-vmbr0}
    
    msg_info "网络配置选项:"
    echo "1) DHCP (自动获取 IP)"
    echo "2) 静态 IP"
    read -p "请选择 (1/2, 默认: 1): " NET_CHOICE
    NET_CHOICE=${NET_CHOICE:-1}
    
    if [ "$NET_CHOICE" == "2" ]; then
        read -p "请输入静态 IP (例如: 192.168.1.101/24): " STATIC_IP
        read -p "请输入网关 (例如: 192.168.1.1): " GATEWAY
        NET_CONFIG="ip=${STATIC_IP},gw=${GATEWAY}"
    else
        NET_CONFIG="ip=dhcp"
    fi
    
    read -sp "请输入 root 密码: " ROOT_PASSWORD
    echo ""
    
    msg_ok "容器配置完成"
}

function download_template() {
    msg_info "检查 Debian 12 模板..."
    
    TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
    
    if ! pveam list local | grep -q "$TEMPLATE"; then
        msg_info "下载 Debian 12 模板..."
        pveam download local $TEMPLATE
        msg_ok "模板下载完成"
    else
        msg_ok "模板已存在"
    fi
}

function create_container() {
    msg_info "正在创建 LXC 容器..."
    
    pct create $CTID local:vztmpl/$TEMPLATE \
        --hostname $CT_NAME \
        --cores $CORES \
        --memory $MEMORY \
        --swap 512 \
        --storage $STORAGE \
        --rootfs $STORAGE:$DISK_SIZE \
        --net0 name=eth0,bridge=$BRIDGE,$NET_CONFIG \
        --password "$ROOT_PASSWORD" \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --ostype debian
    
    msg_ok "容器创建成功 (ID: $CTID)"
}

function start_container() {
    msg_info "启动容器..."
    pct start $CTID
    sleep 5
    msg_ok "容器已启动"
}

function install_adguardhome() {
    msg_info "在容器中安装 AdGuard Home..."
    
    cat > /tmp/adguardhome-install-$CTID.sh <<"'INSTALL_SCRIPT'"
#!/bin/bash
set -e

# 更新系统
apt-get update
apt-get upgrade -y

# 安装依赖
apt-get install -y curl wget ca-certificates

# 检测架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        AGH_ARCH="linux_amd64"
        ;;
    aarch64)
        AGH_ARCH="linux_arm64"
        ;;
    armv7l)
        AGH_ARCH="linux_armv7"
        ;;
    *)
        echo "不支持的架构: ${ARCH}"
        exit 1
        ;;
esac

# 获取最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${LATEST_VERSION}/AdGuardHome_${AGH_ARCH}.tar.gz"

echo "正在下载 AdGuard Home ${LATEST_VERSION}..."
wget -q --show-progress -O /tmp/adguardhome.tar.gz "${DOWNLOAD_URL}"

# 解压安装
tar -xzf /tmp/adguardhome.tar.gz -C /opt/
rm -f /tmp/adguardhome.tar.gz

# 安装为服务
cd /opt/AdGuardHome
./AdGuardHome -s install

# 创建配置目录
mkdir -p /opt/AdGuardHome/data

echo "AdGuard Home 安装完成！版本: ${LATEST_VERSION}"
'INSTALL_SCRIPT'
    
    pct push $CTID /tmp/adguardhome-install-$CTID.sh /tmp/install.sh
    pct exec $CTID -- bash /tmp/install.sh
    pct exec $CTID -- rm /tmp/install.sh
    rm /tmp/adguardhome-install-$CTID.sh
    
    msg_ok "AdGuard Home 安装完成"
}

function show_info() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           AdGuard Home 容器部署完成！                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    sleep 3
    CONTAINER_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}容器信息:${NC}"
    echo "  容器 ID: $CTID"
    echo "  容器名称: $CT_NAME"
    echo "  容器 IP: $CONTAINER_IP"
    echo ""
    echo -e "${GREEN}AdGuard Home 服务:${NC}"
    echo "  管理面板: http://$CONTAINER_IP:3000"
    echo "  DNS 服务: $CONTAINER_IP:53"
    echo ""
    echo -e "${YELLOW}⚠️  首次访问配置:${NC}"
    echo "  1. 浏览器访问: http://$CONTAINER_IP:3000"
    echo "  2. 按照向导完成初始配置"
    echo "  3. 设置管理员账号和密码"
    echo "  4. 配置 DNS 监听端口（默认 53）"
    echo ""
    echo -e "${GREEN}管理命令:${NC}"
    echo "  进入容器: pct enter $CTID"
    echo "  停止容器: pct stop $CTID"
    echo "  启动容器: pct start $CTID"
    echo ""
    echo -e "${GREEN}AdGuard Home 管理 (在容器内):${NC}"
    echo "  查看状态: /opt/AdGuardHome/AdGuardHome -s status"
    echo "  重启服务: /opt/AdGuardHome/AdGuardHome -s restart"
    echo "  停止服务: /opt/AdGuardHome/AdGuardHome -s stop"
    echo ""
    echo -e "${BLUE}下一步:${NC}"
    echo "  1. 访问 http://$CONTAINER_IP:3000 完成初始化"
    echo "  2. 导入广告过滤规则"
    echo "  3. 配置路由器/设备 DNS 为: $CONTAINER_IP"
    echo ""
}

function main() {
    show_header
    check_proxmox
    echo ""
    
    get_next_id
    configure_container
    download_template
    create_container
    start_container
    install_adguardhome
    show_info
    
    msg_ok "🎉 全部完成！"
}

main

