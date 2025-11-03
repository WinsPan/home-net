#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# 在 Debian 虚拟机上安装 AdGuard Home

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
║   AdGuard Home 安装脚本 - Debian 虚拟机版           ║
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
    apt-get install -y curl wget ca-certificates
    msg_ok "依赖安装完成"
}

function detect_arch() {
    msg_info "检测系统架构..."
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
            msg_error "不支持的架构: ${ARCH}"
            exit 1
            ;;
    esac
    msg_ok "系统架构: ${ARCH} (AdGuard Home: ${AGH_ARCH})"
}

function download_adguardhome() {
    msg_info "获取最新版本信息..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        msg_error "无法获取最新版本信息"
        exit 1
    fi
    
    msg_ok "最新版本: ${LATEST_VERSION}"
    
    msg_info "下载 AdGuard Home..."
    DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${LATEST_VERSION}/AdGuardHome_${AGH_ARCH}.tar.gz"
    
    if ! wget -q --show-progress -O /tmp/adguardhome.tar.gz "${DOWNLOAD_URL}"; then
        msg_error "下载失败"
        exit 1
    fi
    
    msg_ok "下载完成"
}

function install_adguardhome() {
    msg_info "安装 AdGuard Home..."
    
    tar -xzf /tmp/adguardhome.tar.gz -C /opt/
    rm -f /tmp/adguardhome.tar.gz
    
    msg_ok "AdGuard Home 解压完成"
}

function install_service() {
    msg_info "安装 systemd 服务..."
    
    cd /opt/AdGuardHome
    ./AdGuardHome -s install
    
    msg_ok "服务安装完成"
}

function start_service() {
    msg_info "启动 AdGuard Home 服务..."
    
    /opt/AdGuardHome/AdGuardHome -s start
    
    sleep 2
    
    if /opt/AdGuardHome/AdGuardHome -s status | grep -q "running"; then
        msg_ok "AdGuard Home 服务已启动"
    else
        msg_error "AdGuard Home 服务启动失败"
        exit 1
    fi
}

function show_info() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           AdGuard Home 安装完成！                     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}版本信息:${NC}"
    echo "  AdGuard Home: ${LATEST_VERSION}"
    echo ""
    echo -e "${GREEN}服务信息:${NC}"
    echo "  IP 地址: ${IP}"
    echo "  管理面板: http://${IP}:3000"
    echo "  DNS 服务: ${IP}:53"
    echo ""
    echo -e "${GREEN}安装目录:${NC}"
    echo "  /opt/AdGuardHome"
    echo ""
    echo -e "${GREEN}服务管理:${NC}"
    echo "  启动: /opt/AdGuardHome/AdGuardHome -s start"
    echo "  停止: /opt/AdGuardHome/AdGuardHome -s stop"
    echo "  重启: /opt/AdGuardHome/AdGuardHome -s restart"
    echo "  状态: /opt/AdGuardHome/AdGuardHome -s status"
    echo ""
    echo -e "${YELLOW}⚠️  重要：首次配置${NC}"
    echo "  1. 浏览器访问: http://${IP}:3000"
    echo "  2. 按照向导完成初始化配置"
    echo "  3. 设置管理员账号和密码"
    echo "  4. 配置 DNS 监听端口（保持默认 53）"
    echo ""
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "  1. 完成 Web 界面初始化"
    echo "  2. 配置上游 DNS（指向 mihomo）"
    echo "  3. 添加广告过滤规则"
    echo "  4. 配置路由器 DNS 指向此服务器"
    echo ""
}

function main() {
    show_header
    check_root
    check_debian
    install_dependencies
    detect_arch
    download_adguardhome
    install_adguardhome
    install_service
    start_service
    show_info
    
    msg_ok "🎉 安装完成！"
}

main

