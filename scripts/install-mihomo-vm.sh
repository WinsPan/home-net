#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# 在 Debian 虚拟机上安装 mihomo

set -e

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

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║     mihomo 安装脚本 - Debian 虚拟机版               ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

function check_debian() {
    if [ ! -f /etc/debian_version ]; then
        msg_error "此脚本仅支持 Debian 系统"
        exit 1
    fi
    msg_ok "Debian 系统检测通过"
}

function install_dependencies() {
    msg_info "安装必要依赖..."
    apt-get update
    apt-get install -y curl wget unzip sudo ca-certificates
    msg_ok "依赖安装完成"
}

function detect_arch() {
    msg_info "检测系统架构..."
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
            msg_error "不支持的架构: ${ARCH}"
            exit 1
            ;;
    esac
    msg_ok "系统架构: ${ARCH} (mihomo: ${MIHOMO_ARCH})"
}

function download_mihomo() {
    msg_info "获取最新版本信息..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        msg_error "无法获取最新版本信息"
        exit 1
    fi
    
    msg_ok "最新版本: ${LATEST_VERSION}"
    
    msg_info "下载 mihomo..."
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"
    
    if ! wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"; then
        msg_error "下载失败"
        exit 1
    fi
    
    msg_ok "下载完成"
}

function install_mihomo() {
    msg_info "安装 mihomo..."
    
    gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
    chmod +x /usr/local/bin/mihomo
    rm -f /tmp/mihomo.gz
    
    msg_ok "mihomo 安装完成"
}

function create_config_dir() {
    msg_info "创建配置目录..."
    mkdir -p /etc/mihomo
    mkdir -p /var/log/mihomo
    msg_ok "配置目录创建完成"
}

function create_default_config() {
    msg_info "创建默认配置文件..."
    
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

proxies:
  # 在这里添加您的代理节点
  # 示例：
  # - name: "节点1"
  #   type: ss
  #   server: your-server.com
  #   port: 8388
  #   cipher: aes-256-gcm
  #   password: "your-password"

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
    
    msg_ok "默认配置文件创建完成"
}

function create_systemd_service() {
    msg_info "创建 systemd 服务..."
    
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
    
    msg_ok "systemd 服务创建完成"
}

function start_service() {
    msg_info "启动 mihomo 服务..."
    
    systemctl daemon-reload
    systemctl enable mihomo
    systemctl start mihomo
    
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "mihomo 服务已启动"
    else
        msg_error "mihomo 服务启动失败"
        msg_info "查看日志: journalctl -u mihomo -n 50"
        exit 1
    fi
}

function show_info() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              mihomo 安装完成！                        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}版本信息:${NC}"
    echo "  mihomo: ${LATEST_VERSION}"
    echo ""
    echo -e "${GREEN}服务信息:${NC}"
    echo "  IP 地址: ${IP}"
    echo "  混合端口: ${IP}:7890"
    echo "  控制面板: http://${IP}:9090"
    echo "  DNS 服务: ${IP}:53"
    echo ""
    echo -e "${GREEN}配置文件:${NC}"
    echo "  /etc/mihomo/config.yaml"
    echo ""
    echo -e "${GREEN}服务管理:${NC}"
    echo "  启动: systemctl start mihomo"
    echo "  停止: systemctl stop mihomo"
    echo "  重启: systemctl restart mihomo"
    echo "  状态: systemctl status mihomo"
    echo "  日志: journalctl -u mihomo -f"
    echo ""
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "  1. 编辑配置文件: nano /etc/mihomo/config.yaml"
    echo "  2. 添加您的代理节点"
    echo "  3. 重启服务: systemctl restart mihomo"
    echo "  4. 使用 Yacd 面板: http://yacd.metacubex.one"
    echo "     API 地址: http://${IP}:9090"
    echo ""
}

function main() {
    show_header
    check_root
    check_debian
    install_dependencies
    detect_arch
    download_mihomo
    install_mihomo
    create_config_dir
    create_default_config
    create_systemd_service
    start_service
    show_info
    
    msg_ok "🎉 安装完成！"
}

main

