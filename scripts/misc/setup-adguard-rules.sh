#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# AdGuard Home 规则自动配置脚本

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

function msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║      AdGuard Home 规则自动配置脚本                   ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_adguardhome() {
    if [ ! -f "/opt/AdGuardHome/AdGuardHome" ]; then
        msg_error "未检测到 AdGuard Home 安装!"
        msg_error "请先安装 AdGuard Home"
        exit 1
    fi
    msg_ok "AdGuard Home 检测通过"
}

function show_rule_sets() {
    echo ""
    msg_info "可用的规则套餐："
    echo ""
    echo "  1) 基础套餐（推荐新手）"
    echo "     - anti-AD (国内广告)"
    echo "     - AdGuard DNS Filter (国际广告)"
    echo "     - EasyList (基础规则)"
    echo "     - AdGuard Malware Filter (恶意软件)"
    echo ""
    echo "  2) 进阶套餐（推荐）"
    echo "     - 包含基础套餐所有规则"
    echo "     - AdGuard DNS Filter 中文 (国内优化)"
    echo "     - 乘风视频过滤 (视频广告)"
    echo "     - EasyPrivacy (隐私保护)"
    echo "     - AdGuard Tracking Protection (反追踪)"
    echo ""
    echo "  3) 完整套餐（追求极致）"
    echo "     - 包含进阶套餐所有规则"
    echo "     - AdGuard Social Media Filter (社交媒体)"
    echo "     - AdGuard Mobile Ads (移动端)"
    echo "     - 更多专项规则..."
    echo ""
    echo "  4) 自定义（手动选择规则）"
    echo ""
}

function get_adguard_config_path() {
    # 查找 AdGuardHome.yaml 配置文件
    if [ -f "/opt/AdGuardHome/AdGuardHome.yaml" ]; then
        AGH_CONFIG="/opt/AdGuardHome/AdGuardHome.yaml"
    elif [ -f "/opt/AdGuardHome/data/AdGuardHome.yaml" ]; then
        AGH_CONFIG="/opt/AdGuardHome/data/AdGuardHome.yaml"
    else
        msg_error "找不到 AdGuardHome.yaml 配置文件"
        msg_info "请先完成 AdGuard Home 的初始化配置"
        msg_info "访问: http://$(hostname -I | awk '{print $1}'):3000"
        exit 1
    fi
    msg_ok "配置文件: $AGH_CONFIG"
}

function backup_config() {
    msg_info "备份当前配置..."
    BACKUP_FILE="${AGH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$AGH_CONFIG" "$BACKUP_FILE"
    msg_ok "配置已备份到: $BACKUP_FILE"
}

function add_basic_rules() {
    msg_info "添加基础规则套餐..."
    
    cat > /tmp/adguard_rules_basic.txt <<"EOF"
# 基础规则套餐
# 国内广告 - anti-AD
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt

# 国际广告 - AdGuard DNS Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# 基础规则 - EasyList
https://easylist-downloads.adblockplus.org/easylist.txt

# 恶意软件 - AdGuard Malware Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/malware.txt
EOF
    
    msg_ok "基础规则列表已准备"
}

function add_advanced_rules() {
    msg_info "添加进阶规则套餐..."
    
    cat > /tmp/adguard_rules_advanced.txt <<"EOF"
# 进阶规则套餐
# 国内广告 - anti-AD
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt

# 国内优化 - AdGuard DNS Filter 中文
https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt

# 视频广告 - 乘风视频过滤
https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/mv.txt

# 国际广告 - AdGuard DNS Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# 基础规则 - EasyList
https://easylist-downloads.adblockplus.org/easylist.txt

# 隐私保护 - EasyPrivacy
https://easylist-downloads.adblockplus.org/easyprivacy.txt

# 恶意软件 - AdGuard Malware Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/malware.txt

# 反追踪 - AdGuard Tracking Protection
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/tracking.txt
EOF
    
    msg_ok "进阶规则列表已准备"
}

function add_complete_rules() {
    msg_info "添加完整规则套餐..."
    
    cat > /tmp/adguard_rules_complete.txt <<"EOF"
# 完整规则套餐
# 国内广告 - anti-AD
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt

# 国内优化 - AdGuard DNS Filter 中文
https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt

# 视频广告 - 乘风视频过滤
https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/mv.txt

# 国际广告 - AdGuard DNS Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# 基础规则 - EasyList
https://easylist-downloads.adblockplus.org/easylist.txt

# 中文规则 - EasyList China
https://easylist-downloads.adblockplus.org/easylistchina.txt

# 隐私保护 - EasyPrivacy
https://easylist-downloads.adblockplus.org/easyprivacy.txt

# 恶意软件 - AdGuard Malware Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/malware.txt

# 反追踪 - AdGuard Tracking Protection
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/tracking.txt

# 社交媒体 - AdGuard Social Media Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/social.txt

# 移动端 - AdGuard Mobile Ads
https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_11_Mobile/filter.txt

# YouTube - YouTube Ads
https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/youtubelist.txt
EOF
    
    msg_ok "完整规则列表已准备"
}

function print_rules_info() {
    echo ""
    msg_info "规则已准备完成，请手动导入到 AdGuard Home："
    echo ""
    echo -e "${YELLOW}导入步骤：${NC}"
    echo "1. 访问 AdGuard Home 管理面板"
    echo "   http://$(hostname -I | awk '{print $1}'):3000"
    echo ""
    echo "2. 登录后进入："
    echo "   设置 → DNS 封锁清单 → 添加阻止列表 → 添加自定义列表"
    echo ""
    echo "3. 依次添加以下规则 URL："
    echo ""
    
    while IFS= read -r line; do
        if [[ $line == http* ]]; then
            echo "   $line"
        elif [[ $line == \#* ]] && [[ $line != \#\ * ]]; then
            echo ""
        fi
    done < "$1"
    
    echo ""
    echo "4. 每添加一条规则后点击 '保存'"
    echo ""
    echo "5. 全部添加完成后，点击 '更新' 按钮刷新规则"
    echo ""
}

function setup_upstream_dns() {
    msg_info "配置上游 DNS..."
    
    echo ""
    echo "推荐的上游 DNS 配置（请手动添加）："
    echo ""
    echo "国内 DNS（主要）："
    echo "  https://dns.alidns.com/dns-query"
    echo "  https://doh.pub/dns-query"
    echo ""
    echo "国际 DNS（备用）："
    echo "  https://cloudflare-dns.com/dns-query"
    echo "  https://dns.google/dns-query"
    echo ""
    echo "配置路径："
    echo "  设置 → DNS 设置 → 上游 DNS 服务器"
    echo ""
}

function main() {
    show_header
    
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    check_adguardhome
    get_adguard_config_path
    
    show_rule_sets
    
    read -p "请选择规则套餐 (1-4): " CHOICE
    
    case $CHOICE in
        1)
            backup_config
            add_basic_rules
            RULES_FILE="/tmp/adguard_rules_basic.txt"
            ;;
        2)
            backup_config
            add_advanced_rules
            RULES_FILE="/tmp/adguard_rules_advanced.txt"
            ;;
        3)
            backup_config
            add_complete_rules
            RULES_FILE="/tmp/adguard_rules_complete.txt"
            ;;
        4)
            msg_info "请参考文档手动配置规则"
            msg_info "文档地址: https://github.com/WinsPan/home-net/blob/main/docs/adguardhome-rules.md"
            exit 0
            ;;
        *)
            msg_error "无效的选择"
            exit 1
            ;;
    esac
    
    print_rules_info "$RULES_FILE"
    setup_upstream_dns
    
    echo ""
    msg_ok "规则配置信息已生成！"
    msg_info "规则列表已保存到: $RULES_FILE"
    msg_info "请按照上述步骤手动导入规则"
    echo ""
    msg_warn "提示：规则导入后首次更新可能需要较长时间，请耐心等待"
    echo ""
}

main

