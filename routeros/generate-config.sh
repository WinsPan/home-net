#!/usr/bin/env bash
# RouterOS 配置生成脚本 - 完整分流和去广告

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║   RouterOS 配置生成工具              ║
║   分流 + 去广告 + 容错               ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

function collect_info() {
    header
    
    msg_info "收集配置信息..."
    echo ""
    
    read -p "RouterOS IP [10.0.0.2]: " ROS_IP
    ROS_IP=${ROS_IP:-10.0.0.2}
    
    read -p "mihomo IP [10.0.0.3]: " MIHOMO_IP
    MIHOMO_IP=${MIHOMO_IP:-10.0.0.3}
    
    read -p "AdGuard Home IP [10.0.0.4]: " ADGUARD_IP
    ADGUARD_IP=${ADGUARD_IP:-10.0.0.4}
    
    read -p "LAN 网桥接口 [bridge]: " LAN_BRIDGE
    LAN_BRIDGE=${LAN_BRIDGE:-bridge}
    
    read -p "WAN 接口 [ether1]: " WAN_INTERFACE
    WAN_INTERFACE=${WAN_INTERFACE:-ether1}
    
    read -p "LAN 网段 [10.0.0.0/24]: " LAN_NETWORK
    LAN_NETWORK=${LAN_NETWORK:-10.0.0.0/24}
    
    read -p "DHCP 池起始 [10.0.0.100]: " DHCP_START
    DHCP_START=${DHCP_START:-10.0.0.100}
    
    read -p "DHCP 池结束 [10.0.0.200]: " DHCP_END
    DHCP_END=${DHCP_END:-10.0.0.200}
    
    echo ""
    read -p "是否配置透明代理？(y/n) [n]: " ENABLE_TPROXY
    ENABLE_TPROXY=${ENABLE_TPROXY:-n}
    
    echo ""
    msg_info "配置确认："
    echo "  RouterOS: $ROS_IP"
    echo "  mihomo: $MIHOMO_IP"
    echo "  AdGuard: $ADGUARD_IP"
    echo "  WAN: $WAN_INTERFACE"
    echo "  LAN: $LAN_BRIDGE ($LAN_NETWORK)"
    echo "  DHCP: $DHCP_START - $DHCP_END"
    echo "  透明代理: $ENABLE_TPROXY"
    echo ""
    
    read -p "确认生成配置？(y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        msg_error "用户取消"
    fi
}

function generate_basic_config() {
    cat <<EOF
# =============================================
# BoomDNS RouterOS 完整配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================

# 注意：请根据实际情况修改接口名称和网络配置

# =============================================
# 1. DNS 配置（使用 AdGuard Home）
# =============================================
/ip dns
set servers=${ADGUARD_IP},223.5.5.5,119.29.29.29
set allow-remote-requests=yes

# =============================================
# 2. DHCP 服务器配置
# =============================================
/ip pool
add name=dhcp-pool ranges=${DHCP_START}-${DHCP_END}

/ip dhcp-server
add name=dhcp1 interface=${LAN_BRIDGE} address-pool=dhcp-pool disabled=no

/ip dhcp-server network
add address=${LAN_NETWORK} gateway=${ROS_IP} dns-server=${ADGUARD_IP}

# =============================================
# 3. DNS 劫持（强制使用 AdGuard Home）
# =============================================
/ip firewall nat
add chain=dstnat protocol=udp dst-port=53 action=dst-nat to-addresses=${ADGUARD_IP} to-ports=53 comment="DNS Hijack to AdGuard"

# =============================================
# 4. 防火墙基础规则
# =============================================
/ip firewall filter

# 允许已建立的连接
add chain=input connection-state=established,related action=accept comment="Accept established/related"

# 允许 ICMP（ping）
add chain=input protocol=icmp action=accept comment="Accept ICMP"

# 允许来自 LAN 的连接
add chain=input in-interface=${LAN_BRIDGE} action=accept comment="Accept from LAN"

# 允许必要的服务
add chain=input protocol=tcp dst-port=22 action=accept comment="Accept SSH"
add chain=input protocol=tcp dst-port=8291 action=accept comment="Accept Winbox"

# 拒绝其他入站连接
add chain=input action=drop comment="Drop all else"

# Forward 链规则
add chain=forward connection-state=established,related action=accept comment="Accept established/related"
add chain=forward connection-state=invalid action=drop comment="Drop invalid"
add chain=forward in-interface=${LAN_BRIDGE} action=accept comment="Accept from LAN"

# =============================================
# 5. NAT 规则（上网）
# =============================================
/ip firewall nat
add chain=srcnat out-interface=${WAN_INTERFACE} action=masquerade comment="NAT for Internet"

# =============================================
# 6. 健康检查脚本（容错机制）
# =============================================
/system script
add name=check-adguard-health source={
    # 检查 AdGuard Home 是否在线
    :local agStatus [/ping ${ADGUARD_IP} count=2]
    :if (\$agStatus = 0) do={
        # AdGuard 离线，禁用 DNS 劫持
        /ip firewall nat disable [find comment="DNS Hijack to AdGuard"]
        :log warning "AdGuard Home is DOWN - DNS hijack disabled"
    } else={
        # AdGuard 在线，启用 DNS 劫持
        /ip firewall nat enable [find comment="DNS Hijack to AdGuard"]
        :log info "AdGuard Home is UP - DNS hijack enabled"
    }
}

add name=check-mihomo-health source={
    # 检查 mihomo 是否在线
    :local miStatus [/ping ${MIHOMO_IP} count=2]
    :if (\$miStatus = 0) do={
        :log warning "mihomo is DOWN"
        # 可以在这里添加故障转移逻辑
    } else={
        :log info "mihomo is UP"
    }
}

# =============================================
# 7. 定时任务（每分钟检查一次）
# =============================================
/system scheduler
add name=health-check-adguard on-event=check-adguard-health interval=1m comment="Check AdGuard Home status"
add name=health-check-mihomo on-event=check-mihomo-health interval=1m comment="Check mihomo status"

EOF
}

function generate_transparent_proxy_config() {
    cat <<EOF
# =============================================
# 8. 透明代理配置（高级功能）
# =============================================

# 创建地址列表（不需要代理的设备）
/ip firewall address-list
add list=no-proxy address=${ROS_IP} comment="RouterOS itself"
add list=no-proxy address=${MIHOMO_IP} comment="mihomo server"
add list=no-proxy address=${ADGUARD_IP} comment="AdGuard Home server"

# Mangle 规则（标记需要代理的流量）
/ip firewall mangle
add chain=prerouting src-address=${LAN_NETWORK} src-address-list=!no-proxy dst-address-list=!no-proxy protocol=tcp action=mark-routing new-routing-mark=via-proxy passthrough=yes comment="Mark traffic for proxy"

# 路由规则（将标记的流量路由到 mihomo）
/ip route
add dst-address=0.0.0.0/0 gateway=${MIHOMO_IP} routing-mark=via-proxy comment="Route to mihomo proxy"

# NAT 规则（重定向到 mihomo 代理端口）
/ip firewall nat
add chain=dstnat protocol=tcp src-address=${LAN_NETWORK} src-address-list=!no-proxy action=dst-nat to-addresses=${MIHOMO_IP} to-ports=7890 comment="Redirect to mihomo"

# 注意：
# 1. 透明代理需要在 mihomo 服务器上配置相应的 iptables 规则
# 2. 可能需要根据实际情况调整规则
# 3. 建议先测试后再全网启用

EOF
}

function generate_advanced_features() {
    cat <<EOF
# =============================================
# 9. 高级功能
# =============================================

# 限速规则示例（可选）
# /queue simple
# add name=guest-limit target=${LAN_NETWORK} max-limit=10M/10M

# 端口转发示例（可选）
# /ip firewall nat
# add chain=dstnat dst-port=8080 protocol=tcp action=dst-nat to-addresses=10.0.0.100 to-ports=80 comment="Port Forward Example"

# Guest 网络隔离（可选）
# /interface bridge filter
# add chain=forward in-interface=guest-bridge out-interface=${LAN_BRIDGE} action=drop comment="Isolate guest network"

# =============================================
# 10. 推荐的额外配置
# =============================================

# 时间同步
/system ntp client
set enabled=yes primary-ntp=ntp.aliyun.com secondary-ntp=time.cloudflare.com

# 日志设置
/system logging
add topics=firewall,info action=memory

# 备份建议
# 1. 定期备份配置: /export file=backup
# 2. 保存到安全位置
# 3. 测试恢复流程

EOF
}

function generate_usage_guide() {
    cat <<EOF
# =============================================
# 使用说明
# =============================================

# 1. 应用配置
#    - 复制此文件到 RouterOS
#    - 在 Terminal 中执行: /import file=routeros-config.rsc
#    - 或使用 WinBox 的 "New Terminal" 粘贴执行

# 2. 验证配置
#    - 检查 DNS: /ip dns print
#    - 检查 DHCP: /ip dhcp-server print
#    - 检查防火墙: /ip firewall nat print
#    - 检查定时任务: /system scheduler print

# 3. 测试
#    - 客户端 DHCP 获取 IP
#    - DNS 解析测试: nslookup google.com
#    - 广告过滤测试: 访问 http://testadblock.com
#    - 代理测试: 访问 https://www.google.com

# 4. 监控
#    - 查看日志: /log print
#    - 查看健康检查: /system script run check-adguard-health
#    - 查看防火墙: /ip firewall nat print stats

# 5. 故障排除
#    - 如果 AdGuard 故障，DNS 会自动切换到备用服务器
#    - 如果 mihomo 故障，可以临时禁用透明代理
#    - 查看日志了解详细信息

# =============================================
# 管理地址
# =============================================

# RouterOS: http://${ROS_IP}
# mihomo 面板: http://${MIHOMO_IP}:9090
# AdGuard Home: http://${ADGUARD_IP}:3000

# =============================================
# 客户端代理设置（手动代理模式）
# =============================================

# 如果不使用透明代理，在客户端设置：
# HTTP 代理: ${MIHOMO_IP}:7890
# SOCKS5 代理: ${MIHOMO_IP}:7891

EOF
}

function generate_config() {
    local output_file="routeros-config.rsc"
    
    msg_info "生成配置文件..."
    
    {
        generate_basic_config
        
        if [[ "$ENABLE_TPROXY" =~ ^[Yy]$ ]]; then
            generate_transparent_proxy_config
        fi
        
        generate_advanced_features
        generate_usage_guide
        
    } > "$output_file"
    
    msg_ok "配置文件已生成: $output_file"
}

function show_summary() {
    echo ""
    echo "════════════════════════════════════════"
    msg_ok "配置生成完成！"
    echo "════════════════════════════════════════"
    echo ""
    echo "配置文件: routeros-config.rsc"
    echo ""
    echo "应用步骤:"
    echo "  1. 将配置文件复制到 RouterOS"
    echo "  2. 在 Terminal 执行: /import file=routeros-config.rsc"
    echo "  3. 检查配置是否正确应用"
    echo ""
    echo "配置功能:"
    echo "  ✅ DNS 劫持（强制 AdGuard）"
    echo "  ✅ DHCP 服务器"
    echo "  ✅ 防火墙规则"
    echo "  ✅ NAT（上网）"
    echo "  ✅ 健康检查（容错）"
    
    if [[ "$ENABLE_TPROXY" =~ ^[Yy]$ ]]; then
        echo "  ✅ 透明代理"
    fi
    
    echo ""
    echo "服务地址:"
    echo "  RouterOS: http://${ROS_IP}"
    echo "  mihomo: http://${MIHOMO_IP}:9090"
    echo "  AdGuard: http://${ADGUARD_IP}:3000"
    echo ""
}

function main() {
    collect_info
    generate_config
    show_summary
}

main

