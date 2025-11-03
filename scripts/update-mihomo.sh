#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# mihomo 更新脚本

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

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║            mihomo 更新脚本                           ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

# 检查是否在容器内运行
function check_environment() {
    if [ ! -f "/etc/mihomo/config.yaml" ]; then
        msg_error "未检测到 mihomo 安装！"
        msg_error "此脚本应该在已安装 mihomo 的容器内运行。"
        exit 1
    fi
    msg_ok "环境检查通过"
}

# 获取当前版本
function get_current_version() {
    if [ -f "/usr/local/bin/mihomo" ]; then
        CURRENT_VERSION=$(/usr/local/bin/mihomo -v 2>&1 | grep -oP 'Mihomo \K[^ ]+' || echo "未知")
        msg_info "当前版本: $CURRENT_VERSION"
    else
        CURRENT_VERSION="未安装"
        msg_info "未检测到 mihomo"
    fi
}

# 检测系统架构
function detect_arch() {
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

# 获取最新版本
function get_latest_version() {
    msg_info "检查最新版本..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        msg_error "无法获取最新版本信息"
        exit 1
    fi
    
    msg_ok "最新版本: $LATEST_VERSION"
}

# 比较版本
function compare_versions() {
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        msg_ok "已经是最新版本！"
        read -p "是否强制重新安装？(y/N): " FORCE
        if [ "$FORCE" != "y" ] && [ "$FORCE" != "Y" ]; then
            msg_info "取消更新"
            exit 0
        fi
    else
        msg_info "发现新版本: $CURRENT_VERSION -> $LATEST_VERSION"
    fi
}

# 下载新版本
function download_mihomo() {
    msg_info "下载 mihomo ${LATEST_VERSION}..."
    
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"
    
    if wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"; then
        msg_ok "下载完成"
    else
        msg_error "下载失败！"
        msg_info "尝试使用镜像地址..."
        # 可以添加镜像地址
        exit 1
    fi
}

# 备份当前版本
function backup_current() {
    if [ -f "/usr/local/bin/mihomo" ]; then
        msg_info "备份当前版本..."
        cp /usr/local/bin/mihomo /usr/local/bin/mihomo.backup
        msg_ok "备份完成: /usr/local/bin/mihomo.backup"
    fi
}

# 停止服务
function stop_service() {
    msg_info "停止 mihomo 服务..."
    if systemctl is-active --quiet mihomo; then
        systemctl stop mihomo
        msg_ok "服务已停止"
    else
        msg_info "服务未在运行"
    fi
}

# 安装新版本
function install_mihomo() {
    msg_info "安装新版本..."
    
    gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
    chmod +x /usr/local/bin/mihomo
    rm -f /tmp/mihomo.gz
    
    msg_ok "安装完成"
}

# 验证安装
function verify_installation() {
    msg_info "验证安装..."
    
    if /usr/local/bin/mihomo -v &>/dev/null; then
        NEW_VERSION=$(/usr/local/bin/mihomo -v 2>&1 | grep -oP 'Mihomo \K[^ ]+' || echo "未知")
        msg_ok "验证成功: $NEW_VERSION"
    else
        msg_error "验证失败！"
        msg_info "尝试恢复备份..."
        if [ -f "/usr/local/bin/mihomo.backup" ]; then
            mv /usr/local/bin/mihomo.backup /usr/local/bin/mihomo
            msg_ok "已恢复备份"
        fi
        exit 1
    fi
}

# 启动服务
function start_service() {
    msg_info "启动 mihomo 服务..."
    
    systemctl start mihomo
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败！"
        msg_info "查看日志: journalctl -u mihomo -n 50"
        exit 1
    fi
}

# 清理
function cleanup() {
    msg_info "清理临时文件..."
    
    rm -f /tmp/mihomo.gz
    
    if [ -f "/usr/local/bin/mihomo.backup" ]; then
        read -p "是否删除备份文件？(y/N): " DEL_BACKUP
        if [ "$DEL_BACKUP" = "y" ] || [ "$DEL_BACKUP" = "Y" ]; then
            rm -f /usr/local/bin/mihomo.backup
            msg_ok "备份文件已删除"
        else
            msg_info "保留备份文件: /usr/local/bin/mihomo.backup"
        fi
    fi
    
    msg_ok "清理完成"
}

# 显示更新结果
function show_result() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              mihomo 更新完成！                        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}版本信息:${NC}"
    echo "  更新前: $CURRENT_VERSION"
    echo "  更新后: $NEW_VERSION"
    echo ""
    echo -e "${GREEN}服务状态:${NC}"
    systemctl status mihomo --no-pager -l
    echo ""
    echo -e "${BLUE}常用命令:${NC}"
    echo "  查看日志: journalctl -u mihomo -f"
    echo "  重启服务: systemctl restart mihomo"
    echo "  查看版本: mihomo -v"
    echo ""
}

# 主函数
function main() {
    show_header
    
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    check_environment
    get_current_version
    detect_arch
    get_latest_version
    compare_versions
    
    echo ""
    read -p "确认更新到 ${LATEST_VERSION}？(y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        msg_info "取消更新"
        exit 0
    fi
    
    echo ""
    download_mihomo
    backup_current
    stop_service
    install_mihomo
    verify_installation
    start_service
    cleanup
    show_result
    
    msg_ok "🎉 更新完成！"
}

# 运行主函数
main

