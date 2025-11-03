#!/bin/bash

# BoomDNS 一键部署脚本
# 自动完成所有部署步骤

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 默认配置
MIHOMO_IP="10.0.0.4"
ADGUARD_IP="10.0.0.5"
ROUTEROS_IP="10.0.0.2"
GATEWAY="10.0.0.2"
NETMASK="24"
DNS="8.8.8.8"

function msg_info() { echo -e "${BLUE}[信息]${NC} $1"; }
function msg_success() { echo -e "${GREEN}[成功]${NC} $1"; }
function msg_error() { echo -e "${RED}[错误]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
function msg_step() { echo -e "${CYAN}[步骤]${NC} $1"; }

function show_banner() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                  BoomDNS 一键部署工具                         ║
║                                                              ║
║              智能分流 + 广告过滤 + 容错保护                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_requirements() {
    msg_step "检查系统要求..."
    
    local missing=0
    
    # 检查必需命令
    for cmd in curl ssh sshpass; do
        if ! command -v $cmd &> /dev/null; then
            msg_error "缺少必需命令: $cmd"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        msg_info "安装缺失的工具..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "macOS 用户请运行: brew install sshpass"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Linux 用户请运行: sudo apt install sshpass"
        fi
        exit 1
    fi
    
    msg_success "系统要求检查通过"
}

function welcome() {
    show_banner
    
    cat <<EOF
欢迎使用 BoomDNS 一键部署工具！

本工具将自动完成以下步骤：
  1. 配置 mihomo VM (${MIHOMO_IP})
  2. 配置 AdGuard Home VM (${ADGUARD_IP})
  3. 生成 RouterOS 配置脚本
  4. 验证部署结果

请确保：
  ✓ 已在 Proxmox 创建两个 Debian 12 VM
  ✓ 已配置 VM 的静态 IP 地址
  ✓ 可以通过 SSH 访问两个 VM
  ✓ 拥有 root 密码

EOF

    read -p "按 Enter 继续，Ctrl+C 退出..."
    echo ""
}

function collect_info() {
    msg_step "收集部署信息..."
    echo ""
    
    # mihomo 信息
    echo -e "${CYAN}=== mihomo VM 信息 ===${NC}"
    read -p "mihomo IP 地址 [${MIHOMO_IP}]: " input
    MIHOMO_IP=${input:-$MIHOMO_IP}
    
    read -sp "mihomo root 密码: " MIHOMO_PASSWORD
    echo ""
    
    read -p "机场订阅地址: " SUBSCRIPTION_URL
    while [ -z "$SUBSCRIPTION_URL" ]; do
        msg_error "订阅地址不能为空！"
        read -p "机场订阅地址: " SUBSCRIPTION_URL
    done
    echo ""
    
    # AdGuard Home 信息
    echo -e "${CYAN}=== AdGuard Home VM 信息 ===${NC}"
    read -p "AdGuard Home IP 地址 [${ADGUARD_IP}]: " input
    ADGUARD_IP=${input:-$ADGUARD_IP}
    
    read -sp "AdGuard Home root 密码: " ADGUARD_PASSWORD
    echo ""
    echo ""
    
    # RouterOS 信息
    echo -e "${CYAN}=== RouterOS 信息 ===${NC}"
    read -p "RouterOS IP 地址 [${ROUTEROS_IP}]: " input
    ROUTEROS_IP=${input:-$ROUTEROS_IP}
    
    read -p "网关地址 [${GATEWAY}]: " input
    GATEWAY=${input:-$GATEWAY}
    echo ""
    
    # 确认信息
    echo -e "${CYAN}=== 配置确认 ===${NC}"
    echo "mihomo:       ${MIHOMO_IP}"
    echo "AdGuard Home: ${ADGUARD_IP}"
    echo "RouterOS:     ${ROUTEROS_IP}"
    echo "网关:         ${GATEWAY}"
    echo "订阅地址:     ${SUBSCRIPTION_URL}"
    echo ""
    
    read -p "确认以上信息正确？(y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        msg_error "已取消部署"
        exit 1
    fi
    echo ""
}

function test_ssh_connection() {
    local ip=$1
    local password=$2
    local name=$3
    
    msg_info "测试 ${name} SSH 连接 (${ip})..."
    
    if sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$ip "echo test" &>/dev/null; then
        msg_success "${name} SSH 连接正常"
        return 0
    else
        msg_error "${name} SSH 连接失败"
        msg_warn "请检查："
        echo "  1. VM 是否已启动"
        echo "  2. IP 地址是否正确"
        echo "  3. root 密码是否正确"
        echo "  4. SSH 服务是否运行"
        return 1
    fi
}

function deploy_mihomo() {
    msg_step "部署 mihomo..."
    echo ""
    
    # 测试连接
    if ! test_ssh_connection "$MIHOMO_IP" "$MIHOMO_PASSWORD" "mihomo"; then
        return 1
    fi
    
    msg_info "上传安装脚本..."
    
    # 创建配置文件
    cat > /tmp/mihomo-auto-config.txt <<EOF
1
${SUBSCRIPTION_URL}
EOF
    
    # 上传脚本
    if ! curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh -o /tmp/install-mihomo.sh; then
        msg_error "下载安装脚本失败"
        return 1
    fi
    
    msg_info "开始安装 mihomo（约需 2-5 分钟）..."
    
    # 上传脚本到服务器
    sshpass -p "$MIHOMO_PASSWORD" scp -o StrictHostKeyChecking=no \
        /tmp/install-mihomo.sh root@${MIHOMO_IP}:/tmp/
    
    # 执行安装
    sshpass -p "$MIHOMO_PASSWORD" ssh -o StrictHostKeyChecking=no root@${MIHOMO_IP} \
        "bash /tmp/install-mihomo.sh" <<ANSWERS
1
${SUBSCRIPTION_URL}
ANSWERS
    
    if [ $? -eq 0 ]; then
        msg_success "mihomo 安装完成"
        echo ""
        msg_info "mihomo 信息："
        echo "  - HTTP 代理:  http://${MIHOMO_IP}:7890"
        echo "  - SOCKS5:     ${MIHOMO_IP}:7891"
        echo "  - 管理界面:   http://${MIHOMO_IP}:9090"
        echo ""
        return 0
    else
        msg_error "mihomo 安装失败"
        return 1
    fi
}

function deploy_adguard() {
    msg_step "部署 AdGuard Home..."
    echo ""
    
    # 测试连接
    if ! test_ssh_connection "$ADGUARD_IP" "$ADGUARD_PASSWORD" "AdGuard Home"; then
        return 1
    fi
    
    msg_info "上传安装脚本..."
    
    # 下载脚本
    if ! curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh -o /tmp/install-adguard.sh; then
        msg_error "下载安装脚本失败"
        return 1
    fi
    
    msg_info "开始安装 AdGuard Home（约需 2-3 分钟）..."
    
    # 上传并执行
    sshpass -p "$ADGUARD_PASSWORD" scp -o StrictHostKeyChecking=no \
        /tmp/install-adguard.sh root@${ADGUARD_IP}:/tmp/
    
    sshpass -p "$ADGUARD_PASSWORD" ssh -o StrictHostKeyChecking=no root@${ADGUARD_IP} \
        "bash /tmp/install-adguard.sh"
    
    if [ $? -eq 0 ]; then
        msg_success "AdGuard Home 安装完成"
        echo ""
        msg_warn "重要：请手动完成 AdGuard Home 初始化"
        echo ""
        echo "1. 浏览器打开: http://${ADGUARD_IP}:3000"
        echo "2. 完成初始化向导（设置管理员账号）"
        echo "3. 配置 DNS 设置（参考文档）"
        echo ""
        read -p "完成初始化后按 Enter 继续..."
        return 0
    else
        msg_error "AdGuard Home 安装失败"
        return 1
    fi
}

function generate_routeros_config() {
    msg_step "生成 RouterOS 配置脚本..."
    echo ""
    
    local config_file="routeros-config.rsc"
    
    cat > $config_file <<EOF
# BoomDNS RouterOS 配置脚本
# 生成时间: $(date)
# 
# 使用方法：
# 1. 复制以下内容
# 2. 登录 RouterOS（Winbox 或 SSH）
# 3. 打开终端，逐行粘贴执行

# ===== DNS 配置（容错） =====
/ip dns set servers=${ADGUARD_IP},223.5.5.5,119.29.29.29 allow-remote-requests=yes cache-size=10240

# ===== DHCP 配置 =====
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool

/ip dhcp-server network add address=10.0.0.0/24 gateway=${GATEWAY} \\
    dns-server=${ADGUARD_IP},223.5.5.5,119.29.29.29

# ===== DNS 劫持（可选但推荐） =====
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 \\
    dst-address=!${ADGUARD_IP} action=dst-nat to-addresses=${ADGUARD_IP} \\
    comment="DNS Hijack"

# ===== 防火墙规则 =====
# INPUT 链（保护路由器）
/ip firewall filter add chain=input connection-state=established,related \\
    action=accept comment="Accept established"

/ip firewall filter add chain=input src-address=10.0.0.0/24 \\
    action=accept comment="Accept from LAN"

/ip firewall filter add chain=input protocol=icmp \\
    action=accept comment="Accept ICMP"

/ip firewall filter add chain=input action=drop \\
    comment="Drop all other"

# FORWARD 链（加速转发）
/ip firewall filter add chain=forward connection-state=established,related \\
    action=fasttrack-connection comment="FastTrack"

/ip firewall filter add chain=forward connection-state=established,related \\
    action=accept comment="Accept established"

# NAT（网络地址转换）
# 注意：请将 ether1 替换为你的 WAN 口名称
/ip firewall nat add chain=srcnat out-interface=ether1 \\
    action=masquerade comment="Masquerade"

# ===== 健康检查脚本（容错关键） =====
/system script add name=check-adguard source={
    :if ([/ping ${ADGUARD_IP} count=2] = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
        /log warning "AdGuard DOWN! DNS hijack disabled."
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}

# 创建定时任务（每分钟检查）
/system scheduler add name=check-schedule on-event=check-adguard \\
    interval=1m comment="Health check"

# ===== 完成 =====
# 配置已完成！请验证：
# /ip dns print
# /ip dhcp-server print
# /ip firewall nat print
EOF

    msg_success "RouterOS 配置已生成: ${config_file}"
    echo ""
    msg_info "请按以下步骤配置 RouterOS："
    echo "  1. 打开文件: ${config_file}"
    echo "  2. 复制所有内容"
    echo "  3. 登录 RouterOS (Winbox 或 SSH)"
    echo "  4. 打开终端，逐行粘贴执行"
    echo ""
    msg_warn "注意：请确认将 'ether1' 替换为你的实际 WAN 口名称"
    echo ""
    read -p "配置完成后按 Enter 继续..."
}

function verify_deployment() {
    msg_step "验证部署..."
    echo ""
    
    msg_info "下载验证脚本..."
    if curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/verify-deployment.sh -o /tmp/verify.sh; then
        msg_info "运行验证测试..."
        bash /tmp/verify.sh
    else
        msg_warn "无法下载验证脚本，请手动测试"
        echo ""
        msg_info "手动测试步骤："
        echo "  1. 测试代理: curl -x http://${MIHOMO_IP}:7890 https://www.google.com -I"
        echo "  2. 测试 DNS: nslookup google.com ${ADGUARD_IP}"
        echo "  3. 访问管理界面:"
        echo "     - mihomo: http://${MIHOMO_IP}:9090"
        echo "     - AdGuard: http://${ADGUARD_IP}"
    fi
}

function show_summary() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo ""
    msg_success "部署完成！"
    echo ""
    
    cat <<EOF
${GREEN}部署信息总结：${NC}

${CYAN}服务地址：${NC}
  mihomo HTTP 代理:  http://${MIHOMO_IP}:7890
  mihomo SOCKS5:     ${MIHOMO_IP}:7891
  mihomo 管理界面:   http://${MIHOMO_IP}:9090
  
  AdGuard Home:      http://${ADGUARD_IP}
  
  RouterOS:          ${ROUTEROS_IP}

${CYAN}下一步操作：${NC}

1. ${YELLOW}配置设备代理（二选一）${NC}

   ${GREEN}方式 A：手动设置（推荐新手）${NC}
   在设备上设置代理: ${MIHOMO_IP}:7890
   
   Windows:  设置 → 网络 → 代理
   macOS:    系统偏好设置 → 网络 → 代理
   浏览器:   安装 SwitchyOmega 扩展
   
   ${GREEN}方式 B：透明代理（高级）${NC}
   查看文档: https://github.com/WinsPan/home-net/blob/main/docs/CONFIG.md

2. ${YELLOW}测试功能${NC}

   # 测试广告拦截
   访问: http://testadblock.com
   
   # 测试代理
   curl -x http://${MIHOMO_IP}:7890 https://www.google.com -I

3. ${YELLOW}管理界面${NC}

   mihomo:       http://${MIHOMO_IP}:9090
   AdGuard Home: http://${ADGUARD_IP}

${CYAN}故障排查：${NC}

  # 运行诊断工具
  curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/diagnose.sh | bash

${CYAN}快速参考：${NC}

  查看文档: https://github.com/WinsPan/home-net
  
  GUIDE.md       - 完整部署指南
  CHEATSHEET.md  - 常用命令速查
  CONFIG.md      - 高级配置

${CYAN}生成的文件：${NC}

  routeros-config.rsc  - RouterOS 配置脚本

EOF

    echo "════════════════════════════════════════════════════════"
    echo ""
    msg_success "感谢使用 BoomDNS！"
    echo ""
}

function cleanup() {
    rm -f /tmp/install-mihomo.sh
    rm -f /tmp/install-adguard.sh
    rm -f /tmp/mihomo-auto-config.txt
    rm -f /tmp/verify.sh
}

function main() {
    # 检查系统要求
    check_requirements
    
    # 欢迎界面
    welcome
    
    # 收集信息
    collect_info
    
    # 部署 mihomo
    if ! deploy_mihomo; then
        msg_error "mihomo 部署失败，请检查日志"
        exit 1
    fi
    
    # 部署 AdGuard Home
    if ! deploy_adguard; then
        msg_error "AdGuard Home 部署失败，请检查日志"
        exit 1
    fi
    
    # 生成 RouterOS 配置
    generate_routeros_config
    
    # 验证部署
    verify_deployment
    
    # 显示总结
    show_summary
    
    # 清理临时文件
    cleanup
}

# 捕获退出信号
trap cleanup EXIT

# 运行主程序
main

