#!/bin/bash

# BoomDNS 全自动部署脚本
# 自动创建 VM + 安装配置 + 验证部署

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
MIHOMO_VMID="100"
ADGUARD_VMID="101"
MIHOMO_IP="10.0.0.4"
ADGUARD_IP="10.0.0.5"
GATEWAY="10.0.0.2"
NETMASK="24"
DNS="8.8.8.8"
DEBIAN_ISO="debian-12-generic-amd64.iso"

function msg_info() { echo -e "${BLUE}[信息]${NC} $1"; }
function msg_success() { echo -e "${GREEN}[✓]${NC} $1"; }
function msg_error() { echo -e "${RED}[✗]${NC} $1"; }
function msg_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
function msg_step() { echo -e "${CYAN}[▶]${NC} $1"; }

function show_banner() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║         BoomDNS 全自动一键部署                        ║
║    自动创建VM → 安装系统 → 配置服务 → 完成部署        ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_proxmox() {
    msg_step "检查 Proxmox 环境..."
    
    if ! command -v pvesh &>/dev/null; then
        msg_error "未检测到 Proxmox 环境"
        msg_info "请在 Proxmox VE 节点上运行此脚本"
        exit 1
    fi
    
    # 检查是否有 root 权限
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行"
        exit 1
    fi
    
    msg_success "Proxmox 环境检查通过"
}

function collect_info() {
    msg_step "收集部署信息..."
    echo ""
    
    # Proxmox 节点
    read -p "Proxmox 节点名称 (按 Enter 使用当前节点): " PVE_NODE
    PVE_NODE=${PVE_NODE:-$(hostname)}
    
    # 存储
    read -p "存储池名称 [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    # 网络桥接
    read -p "网络桥接 [vmbr0]: " BRIDGE
    BRIDGE=${BRIDGE:-vmbr0}
    
    # 网络配置
    read -p "mihomo IP [${MIHOMO_IP}]: " input
    MIHOMO_IP=${input:-$MIHOMO_IP}
    
    read -p "AdGuard Home IP [${ADGUARD_IP}]: " input
    ADGUARD_IP=${input:-$ADGUARD_IP}
    
    read -p "网关 [${GATEWAY}]: " input
    GATEWAY=${input:-$GATEWAY}
    
    # Root 密码
    read -sp "VM root 密码: " ROOT_PASSWORD
    echo ""
    
    # 机场订阅
    read -p "机场订阅地址: " SUBSCRIPTION_URL
    while [ -z "$SUBSCRIPTION_URL" ]; do
        msg_error "订阅地址不能为空"
        read -p "机场订阅地址: " SUBSCRIPTION_URL
    done
    
    echo ""
    msg_info "配置确认："
    echo "  节点: ${PVE_NODE}"
    echo "  存储: ${STORAGE}"
    echo "  网桥: ${BRIDGE}"
    echo "  mihomo: ${MIHOMO_IP}"
    echo "  AdGuard: ${ADGUARD_IP}"
    echo "  网关: ${GATEWAY}"
    echo ""
    
    read -p "确认无误？(y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        msg_error "已取消"
        exit 1
    fi
}

function create_vm() {
    local vmid=$1
    local name=$2
    local cores=$3
    local memory=$4
    local disk=$5
    local ip=$6
    
    msg_step "创建 VM ${vmid} (${name})..."
    
    # 检查 VM 是否已存在
    if pvesh get /nodes/${PVE_NODE}/qemu/${vmid}/status/current &>/dev/null; then
        msg_warn "VM ${vmid} 已存在"
        read -p "删除重建？(y/n): " rebuild
        if [[ $rebuild =~ ^[Yy]$ ]]; then
            msg_info "删除旧 VM..."
            pvesh delete /nodes/${PVE_NODE}/qemu/${vmid} || true
            sleep 3
        else
            msg_info "跳过 VM 创建"
            return 0
        fi
    fi
    
    # 创建 VM
    msg_info "创建虚拟机..."
    pvesh create /nodes/${PVE_NODE}/qemu \
        -vmid ${vmid} \
        -name ${name} \
        -cores ${cores} \
        -memory ${memory} \
        -net0 "virtio,bridge=${BRIDGE}" \
        -ostype l26 \
        -scsihw virtio-scsi-pci \
        -bootdisk scsi0 \
        -scsi0 "${STORAGE}:${disk}" \
        -ide2 "local:iso/${DEBIAN_ISO},media=cdrom" \
        -boot "order=ide2;scsi0" \
        -agent 1
    
    msg_success "VM ${vmid} 创建完成"
}

function install_debian() {
    local vmid=$1
    local name=$2
    local ip=$3
    
    msg_step "在 VM ${vmid} 安装 Debian..."
    
    msg_info "启动 VM 并等待系统安装..."
    msg_warn "请在 Proxmox 控制台完成 Debian 安装："
    echo "  1. 选择 Install"
    echo "  2. 语言: English"
    echo "  3. 主机名: ${name}"
    echo "  4. Root 密码: 你设置的密码"
    echo "  5. 分区: Guided - use entire disk"
    echo "  6. 软件: 只选 SSH server"
    echo "  7. 完成安装后重启"
    echo ""
    
    # 启动 VM
    pvesh create /nodes/${PVE_NODE}/qemu/${vmid}/status/start
    
    msg_warn "系统安装通常需要 5-10 分钟"
    read -p "安装完成后按 Enter 继续..."
}

function configure_network() {
    local ip=$1
    local name=$2
    
    msg_step "配置 ${name} 网络..."
    
    # 等待 SSH 可用
    msg_info "等待 SSH 服务启动..."
    local retry=0
    while [ $retry -lt 30 ]; do
        if sshpass -p "${ROOT_PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 root@${ip} "echo test" &>/dev/null; then
            msg_success "SSH 连接成功"
            break
        fi
        retry=$((retry + 1))
        sleep 5
    done
    
    if [ $retry -eq 30 ]; then
        msg_error "SSH 连接超时"
        msg_info "请手动配置网络："
        echo "  编辑: /etc/network/interfaces"
        echo "  设置: ${ip}/24"
        echo "  网关: ${GATEWAY}"
        read -p "配置完成后按 Enter 继续..."
        return
    fi
    
    # 配置静态 IP
    msg_info "设置静态 IP..."
    sshpass -p "${ROOT_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${ip} "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address ${ip}/${NETMASK}
    gateway ${GATEWAY}
    dns-nameservers ${DNS}
EOF"
    
    # 重启网络
    sshpass -p "${ROOT_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${ip} "systemctl restart networking"
    
    msg_success "网络配置完成"
}

function install_mihomo() {
    msg_step "安装 mihomo..."
    
    # 下载安装脚本
    curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh -o /tmp/install-mihomo.sh
    
    # 上传并执行
    sshpass -p "${ROOT_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/install-mihomo.sh root@${MIHOMO_IP}:/tmp/
    sshpass -p "${ROOT_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${MIHOMO_IP} \
        "AUTO_CONFIG_CHOICE=1 AUTO_SUBSCRIPTION_URL='${SUBSCRIPTION_URL}' bash /tmp/install-mihomo.sh"
    
    msg_success "mihomo 安装完成"
}

function install_adguard() {
    msg_step "安装 AdGuard Home..."
    
    # 下载安装脚本
    curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh -o /tmp/install-adguard.sh
    
    # 上传并执行
    sshpass -p "${ROOT_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/install-adguard.sh root@${ADGUARD_IP}:/tmp/
    sshpass -p "${ROOT_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${ADGUARD_IP} "bash /tmp/install-adguard.sh"
    
    msg_success "AdGuard Home 安装完成"
    msg_info "请访问 http://${ADGUARD_IP}:3000 完成初始化"
}

function generate_routeros_config() {
    msg_step "生成 RouterOS 配置..."
    
    cat > routeros-config.rsc <<EOF
# BoomDNS RouterOS 配置
# 生成时间: $(date)

# DNS 配置（容错）
/ip dns set servers=${ADGUARD_IP},223.5.5.5,119.29.29.29 allow-remote-requests=yes

# DHCP 配置
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=${GATEWAY} dns-server=${ADGUARD_IP},223.5.5.5

# DNS 劫持
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 dst-address=!${ADGUARD_IP} \\
    action=dst-nat to-addresses=${ADGUARD_IP} comment="DNS Hijack"

# 防火墙
/ip firewall filter add chain=input connection-state=established,related action=accept
/ip firewall filter add chain=input src-address=10.0.0.0/24 action=accept
/ip firewall filter add chain=input protocol=icmp action=accept
/ip firewall filter add chain=input action=drop

# NAT (修改 ether1 为你的 WAN 口)
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade

# 健康检查
/system script add name=check-adguard source={
    :if ([/ping ${ADGUARD_IP} count=2] = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}
/system scheduler add name=check-schedule on-event=check-adguard interval=1m
EOF

    msg_success "RouterOS 配置已生成: routeros-config.rsc"
}

function show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════"
    msg_success "部署完成！"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "服务地址："
    echo "  mihomo:       http://${MIHOMO_IP}:9090"
    echo "  AdGuard Home: http://${ADGUARD_IP}:3000"
    echo ""
    echo "下一步："
    echo "  1. 访问 http://${ADGUARD_IP}:3000 初始化 AdGuard"
    echo "  2. 在 RouterOS 执行: routeros-config.rsc"
    echo "  3. 设置设备代理: ${MIHOMO_IP}:7890"
    echo ""
    echo "文档：https://github.com/WinsPan/home-net"
    echo "═══════════════════════════════════════════════"
}

function main() {
    show_banner
    
    msg_info "全自动部署：创建VM → 安装系统 → 配置服务"
    echo ""
    
    # 检查环境
    check_proxmox
    
    # 收集信息
    collect_info
    
    # 创建 mihomo VM
    create_vm ${MIHOMO_VMID} "mihomo" 2 2048 20 ${MIHOMO_IP}
    
    # 创建 AdGuard Home VM
    create_vm ${ADGUARD_VMID} "adguardhome" 1 1024 10 ${ADGUARD_IP}
    
    # 安装系统
    msg_warn "请分别在 Proxmox 控制台完成两个 VM 的系统安装"
    install_debian ${MIHOMO_VMID} "mihomo" ${MIHOMO_IP}
    install_debian ${ADGUARD_VMID} "adguardhome" ${ADGUARD_IP}
    
    # 配置网络
    configure_network ${MIHOMO_IP} "mihomo"
    configure_network ${ADGUARD_IP} "adguardhome"
    
    # 安装服务
    install_mihomo
    install_adguard
    
    # 生成 RouterOS 配置
    generate_routeros_config
    
    # 显示总结
    show_summary
}

main
