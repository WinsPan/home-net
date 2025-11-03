#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# 在 Proxmox VE 上自动创建 Debian LXC 容器并安装 mihomo

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
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

# 显示 logo
function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║     __  ____  __  ______  __  _______                ║
║    /  |/  / / / / / / __ \/  |/  / __ \             ║
║   / /|_/ / / /_/ / / / / / /|_/ / / / /             ║
║  / /  / / / __  / / /_/ / /  / / /_/ /              ║
║ /_/  /_/ /_/ /_/  \____/_/  /_/\____/               ║
║                                                      ║
║      mihomo LXC 容器自动部署脚本                     ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

# 检查是否在 Proxmox VE 上运行
function check_proxmox() {
    if ! command -v pct &> /dev/null; then
        msg_error "此脚本必须在 Proxmox VE 主机上运行!"
        exit 1
    fi
    msg_ok "Proxmox VE 环境检测通过"
}

# 获取下一个可用的 CT ID
function get_next_id() {
    CTID=$(pvesh get /cluster/nextid)
    msg_info "建议的容器 ID: $CTID"
    read -p "请输入容器 ID (直接回车使用 $CTID): " USER_CTID
    if [ -n "$USER_CTID" ]; then
        CTID=$USER_CTID
    fi
}

# 配置容器参数
function configure_container() {
    msg_info "配置容器参数..."
    
    # 容器名称
    read -p "请输入容器名称 (默认: mihomo): " CT_NAME
    CT_NAME=${CT_NAME:-mihomo}
    
    # 存储位置
    pvesm status | awk 'NR>1 {print $1}' | grep -v "^Type$"
    read -p "请选择存储位置 (默认: local-lvm): " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    # 磁盘大小
    read -p "请输入磁盘大小 (GB, 默认: 4): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-4}
    
    # CPU 核心数
    read -p "请输入 CPU 核心数 (默认: 2): " CORES
    CORES=${CORES:-2}
    
    # 内存大小
    read -p "请输入内存大小 (MB, 默认: 1024): " MEMORY
    MEMORY=${MEMORY:-1024}
    
    # 网络桥接
    read -p "请输入网络桥接 (默认: vmbr0): " BRIDGE
    BRIDGE=${BRIDGE:-vmbr0}
    
    # IP 配置
    msg_info "网络配置选项:"
    echo "1) DHCP (自动获取 IP)"
    echo "2) 静态 IP"
    read -p "请选择 (1/2, 默认: 1): " NET_CHOICE
    NET_CHOICE=${NET_CHOICE:-1}
    
    if [ "$NET_CHOICE" == "2" ]; then
        read -p "请输入静态 IP (例如: 192.168.1.100/24): " STATIC_IP
        read -p "请输入网关 (例如: 192.168.1.1): " GATEWAY
        NET_CONFIG="ip=${STATIC_IP},gw=${GATEWAY}"
    else
        NET_CONFIG="ip=dhcp"
    fi
    
    # root 密码
    read -sp "请输入 root 密码: " ROOT_PASSWORD
    echo ""
    
    msg_ok "容器配置完成"
}

# 下载 Debian 模板
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

# 创建容器
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

# 启动容器
function start_container() {
    msg_info "启动容器..."
    pct start $CTID
    sleep 5
    msg_ok "容器已启动"
}

# 在容器中安装 mihomo
function install_mihomo() {
    msg_info "在容器中安装 mihomo..."
    
    # 创建安装脚本
    cat > /tmp/mihomo-install-$CTID.sh <<"'INSTALL_SCRIPT'"
#!/bin/bash
set -e

# 更新系统
apt-get update
apt-get upgrade -y

# 安装依赖
apt-get install -y curl wget unzip sudo systemctl ca-certificates

# 检测架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        MIHOMO_ARCH="linux-amd64"
        ;;
    aarch64)
        MIHOMO_ARCH="linux-arm64"
        ;;
    armv7l)
        MIHOMO_ARCH="linux-armv7"
        ;;
    *)
        echo "不支持的架构: ${ARCH}"
        exit 1
        ;;
esac

# 下载 mihomo
LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"

echo "正在下载 mihomo ${LATEST_VERSION}..."
wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"

# 安装 mihomo
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm -f /tmp/mihomo.gz

# 创建配置目录
mkdir -p /etc/mihomo
mkdir -p /var/log/mihomo

# 创建默认配置
cat > /etc/mihomo/config.yaml <<"EOF"
# mihomo 配置文件
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: ""

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

proxies: []

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF

# 创建 systemd 服务
cat > /etc/systemd/system/mihomo.service <<"EOF"
[Unit]
Description=mihomo Daemon, Another Clash Kernel.
After=network.target NetworkManager.service systemd-networkd.service iwd.service

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
Restart=always
ExecStartPre=/usr/bin/sleep 1s
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl daemon-reload
systemctl enable mihomo
systemctl start mihomo

echo "mihomo 安装完成！版本: ${LATEST_VERSION}"
'INSTALL_SCRIPT'
    
    # 复制脚本到容器并执行
    pct push $CTID /tmp/mihomo-install-$CTID.sh /tmp/install.sh
    pct exec $CTID -- bash /tmp/install.sh
    pct exec $CTID -- rm /tmp/install.sh
    rm /tmp/mihomo-install-$CTID.sh
    
    msg_ok "mihomo 安装完成"
}

# 显示容器信息
function show_info() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              mihomo 容器部署完成！                    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    # 获取容器 IP
    sleep 3
    CONTAINER_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}容器信息:${NC}"
    echo "  容器 ID: $CTID"
    echo "  容器名称: $CT_NAME"
    echo "  容器 IP: $CONTAINER_IP"
    echo ""
    echo -e "${GREEN}mihomo 服务:${NC}"
    echo "  混合端口: $CONTAINER_IP:7890"
    echo "  控制面板: http://$CONTAINER_IP:9090"
    echo "  DNS 服务: $CONTAINER_IP:53"
    echo ""
    echo -e "${GREEN}管理命令:${NC}"
    echo "  进入容器: pct enter $CTID"
    echo "  停止容器: pct stop $CTID"
    echo "  启动容器: pct start $CTID"
    echo "  删除容器: pct destroy $CTID"
    echo ""
    echo -e "${GREEN}mihomo 管理 (在容器内):${NC}"
    echo "  查看状态: systemctl status mihomo"
    echo "  重启服务: systemctl restart mihomo"
    echo "  查看日志: journalctl -u mihomo -f"
    echo "  编辑配置: nano /etc/mihomo/config.yaml"
    echo ""
    echo -e "${YELLOW}推荐工具:${NC}"
    echo "  Yacd 面板: http://yacd.metacubex.one"
    echo "  连接到控制器: http://$CONTAINER_IP:9090"
    echo ""
    echo -e "${BLUE}下一步:${NC}"
    echo "  1. pct enter $CTID"
    echo "  2. nano /etc/mihomo/config.yaml  # 添加您的代理节点"
    echo "  3. systemctl restart mihomo      # 重启服务"
    echo ""
}

# 主函数
function main() {
    show_header
    check_proxmox
    echo ""
    
    get_next_id
    configure_container
    download_template
    create_container
    start_container
    install_mihomo
    show_info
    
    msg_ok "🎉 全部完成！"
}

# 运行主函数
main

