#!/bin/bash
# BoomDNS 一键部署脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
MIHOMO_VMID="101"
ADGUARD_VMID="102"
MIHOMO_IP="10.0.0.3"
ADGUARD_IP="10.0.0.4"
GATEWAY="10.0.0.2"
NETMASK="24"

function msg_info() { echo -e "${BLUE}[信息]${NC} $1"; }
function msg_success() { echo -e "${GREEN}[✓]${NC} $1"; }
function msg_error() { echo -e "${RED}[✗]${NC} $1"; }
function msg_step() { echo -e "${CYAN}[▶]${NC} $1"; }

function show_banner() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║      BoomDNS 一键部署                ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

function check_env() {
    msg_step "检查环境..."
    
    if ! command -v qm &>/dev/null; then
        msg_error "需要在 Proxmox 节点运行"
        exit 1
    fi
    
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限"
        exit 1
    fi
    
    msg_success "环境检查通过"
}

function collect_info() {
    msg_step "收集配置..."
    echo ""
    
    exec 3<&0 < /dev/tty
    
    read -p "Proxmox 节点 [$(hostname)]: " PVE_NODE
    PVE_NODE=${PVE_NODE:-$(hostname)}
    
    read -p "存储池 [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    read -p "网桥 [vmbr0]: " BRIDGE
    BRIDGE=${BRIDGE:-vmbr0}
    
    read -p "mihomo IP [${MIHOMO_IP}]: " input
    MIHOMO_IP=${input:-$MIHOMO_IP}
    
    read -p "AdGuard IP [${ADGUARD_IP}]: " input
    ADGUARD_IP=${input:-$ADGUARD_IP}
    
    read -sp "VM root 密码: " ROOT_PASSWORD
    echo ""
    
    read -p "机场订阅: " SUBSCRIPTION_URL
    while [ -z "$SUBSCRIPTION_URL" ]; do
        msg_error "订阅不能为空"
        read -p "机场订阅: " SUBSCRIPTION_URL
    done
    
    echo ""
    msg_info "配置确认："
    echo "  mihomo: ${MIHOMO_IP}"
    echo "  AdGuard: ${ADGUARD_IP}"
    echo ""
    
    read -p "确认？(y/n): " confirm
    [[ ! $confirm =~ ^[Yy]$ ]] && exit 1
    
    exec 0<&3 3<&-
}

function download_image() {
    msg_step "下载镜像..."
    
    local url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    local file="/var/lib/vz/template/iso/debian-12-cloud.qcow2"
    
    if [ -f "$file" ]; then
        msg_success "镜像已存在"
        return 0
    fi
    
    wget -q --show-progress -O "$file" "$url" || exit 1
    msg_success "下载完成"
}

function create_vm() {
    local vmid=$1
    local name=$2
    local cores=$3
    local memory=$4
    local disk=$5
    local ip=$6
    
    msg_step "创建 ${name} VM..."
    
    # 删除旧 VM
    if qm status $vmid &>/dev/null; then
        qm stop $vmid || true
        sleep 2
        qm destroy $vmid || true
        sleep 2
    fi
    
    # 创建 VM
    qm create $vmid \
        --name $name \
        --cores $cores \
        --memory $memory \
        --net0 virtio,bridge=$BRIDGE \
        --serial0 socket \
        --vga serial0
    
    # 导入磁盘
    qm importdisk $vmid /var/lib/vz/template/iso/debian-12-cloud.qcow2 $STORAGE
    
    # 配置
    qm set $vmid --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${vmid}-disk-0
    qm resize $vmid scsi0 ${disk}G
    qm set $vmid --ide2 ${STORAGE}:cloudinit
    qm set $vmid --boot c --bootdisk scsi0
    qm set $vmid --ipconfig0 ip=${ip}/${NETMASK},gw=${GATEWAY}
    qm set $vmid --nameserver 8.8.8.8
    qm set $vmid --ciuser root
    qm set $vmid --cipassword "$ROOT_PASSWORD"
    
    msg_success "${name} 创建完成"
}

function start_vm() {
    local vmid=$1
    local ip=$2
    local name=$3
    
    msg_step "启动 ${name}..."
    qm start $vmid
    
    msg_info "等待就绪..."
    local retry=0
    while [ $retry -lt 60 ]; do
        if ping -c 1 -W 1 $ip &>/dev/null; then
            sleep 5
            if sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 root@$ip "echo ready" &>/dev/null; then
                msg_success "${name} 就绪"
                return 0
            fi
        fi
        retry=$((retry + 1))
        sleep 5
    done
    
    msg_error "${name} 启动超时"
    exit 1
}

function install_services() {
    msg_step "安装服务..."
    
    # 安装 mihomo
    msg_info "安装 mihomo..."
    curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh | \
        sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@${MIHOMO_IP} \
        "AUTO_CONFIG_CHOICE=1 AUTO_SUBSCRIPTION_URL='${SUBSCRIPTION_URL}' bash"
    
    # 安装 AdGuard
    msg_info "安装 AdGuard Home..."
    curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh | \
        sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@${ADGUARD_IP} bash
    
    msg_success "服务安装完成"
}

function generate_config() {
    msg_step "生成配置..."
    
    cat > routeros-config.rsc <<EOF
# BoomDNS RouterOS 配置

/ip dns set servers=${ADGUARD_IP},223.5.5.5
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=${GATEWAY} dns-server=${ADGUARD_IP}
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 action=dst-nat to-addresses=${ADGUARD_IP}
/ip firewall filter add chain=input connection-state=established,related action=accept
/ip firewall filter add chain=input src-address=10.0.0.0/24 action=accept
/ip firewall filter add chain=input action=drop
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
EOF

    msg_success "配置已生成: routeros-config.rsc"
}

function show_summary() {
    echo ""
    echo "══════════════════════════════════════"
    msg_success "部署完成！"
    echo "══════════════════════════════════════"
    echo ""
    echo "服务:"
    echo "  mihomo:       http://${MIHOMO_IP}:9090"
    echo "  AdGuard Home: http://${ADGUARD_IP}:3000"
    echo ""
    echo "下一步:"
    echo "  1. 初始化 AdGuard: http://${ADGUARD_IP}:3000"
    echo "  2. 执行 RouterOS 配置: routeros-config.rsc"
    echo "  3. 设置代理: ${MIHOMO_IP}:7890"
    echo ""
}

function main() {
    show_banner
    check_env
    collect_info
    
    echo ""
    msg_step "开始部署..."
    echo ""
    
    download_image
    
    create_vm ${MIHOMO_VMID} "mihomo" 2 2048 20 ${MIHOMO_IP}
    create_vm ${ADGUARD_VMID} "adguardhome" 1 1024 10 ${ADGUARD_IP}
    
    start_vm ${MIHOMO_VMID} ${MIHOMO_IP} "mihomo"
    start_vm ${ADGUARD_VMID} ${ADGUARD_IP} "adguardhome"
    
    install_services
    generate_config
    
    show_summary
}

main
