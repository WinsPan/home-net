#!/usr/bin/env bash
# BoomDNS VM 创建脚本
# 参考: https://github.com/community-scripts/ProxmoxVE

set -e

# 颜色定义
YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;92m'
CL='\033[m'

function msg_info() { echo -e "${BL}[INFO]${CL} $1"; }
function msg_ok() { echo -e "${GN}[OK]${CL} $1"; }
function msg_error() { echo -e "${RD}[ERROR]${CL} $1"; exit 1; }

function header_info() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════╗
║      BoomDNS VM 创建工具             ║
║   基于 Debian 13 Cloud-init          ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

# 检查 root 权限
function check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        msg_error "需要 root 权限运行此脚本"
    fi
}

# 检查 Proxmox 环境
function check_proxmox() {
    if ! command -v qm &>/dev/null; then
        msg_error "未检测到 Proxmox 环境"
    fi
    msg_ok "环境检查通过"
}

# 获取有效的 VMID
function get_valid_vmid() {
    local try_id
    try_id=$(pvesh get /cluster/nextid 2>/dev/null || echo "100")
    
    while true; do
        if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
            try_id=$((try_id + 1))
            continue
        fi
        
        if lvs --noheadings -o lv_name 2>/dev/null | grep -qE "(^|[-_])${try_id}($|[-_])"; then
            try_id=$((try_id + 1))
            continue
        fi
        
        break
    done
    
    echo "$try_id"
}

# 交互式配置
function interactive_config() {
    header_info
    
    # VM 名称
    read -p "VM 名称 [mihomo]: " VM_NAME
    VM_NAME=${VM_NAME:-mihomo}
    
    # VMID
    DEFAULT_VMID=$(get_valid_vmid)
    read -p "VMID [$DEFAULT_VMID]: " VMID
    VMID=${VMID:-$DEFAULT_VMID}
    
    # CPU 核心数
    read -p "CPU 核心数 [2]: " CPU_CORES
    CPU_CORES=${CPU_CORES:-2}
    
    # 内存大小 (MB)
    read -p "内存大小 MB [2048]: " MEMORY
    MEMORY=${MEMORY:-2048}
    
    # 磁盘大小 (GB)
    read -p "磁盘大小 GB [20]: " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-20}
    
    # 存储池
    msg_info "可用存储池："
    pvesm status -content images | awk 'NR>1 {print "  - " $1 " (" $2 ")"}'
    read -p "存储池 [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    # 网桥
    read -p "网桥 [vmbr0]: " BRIDGE
    BRIDGE=${BRIDGE:-vmbr0}
    
    # IP 配置
    read -p "静态 IP (例如: 10.0.0.3/24): " VM_IP
    while [ -z "$VM_IP" ]; do
        msg_error "IP 地址不能为空"
        read -p "静态 IP: " VM_IP
    done
    
    read -p "网关 [10.0.0.2]: " GATEWAY
    GATEWAY=${GATEWAY:-10.0.0.2}
    
    read -p "DNS 服务器 [8.8.8.8]: " DNS
    DNS=${DNS:-8.8.8.8}
    
    # SSH 配置
    read -sp "root 密码: " ROOT_PASSWORD
    echo ""
    
    read -p "是否添加 SSH 公钥？(y/n) [n]: " ADD_SSH_KEY
    if [[ "$ADD_SSH_KEY" =~ ^[Yy]$ ]]; then
        read -p "SSH 公钥路径 [~/.ssh/id_rsa.pub]: " SSH_KEY_PATH
        SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa.pub}
        
        if [ -f "$SSH_KEY_PATH" ]; then
            SSH_KEY=$(cat "$SSH_KEY_PATH")
        else
            msg_error "SSH 公钥文件不存在"
        fi
    fi
    
    # 自动启动
    read -p "是否随 Proxmox 自动启动？(y/n) [y]: " AUTO_START
    AUTO_START=${AUTO_START:-y}
    
    # 确认配置
    echo ""
    msg_info "配置确认："
    echo "  VM 名称: $VM_NAME"
    echo "  VMID: $VMID"
    echo "  CPU: $CPU_CORES 核心"
    echo "  内存: $MEMORY MB"
    echo "  磁盘: $DISK_SIZE GB"
    echo "  存储: $STORAGE"
    echo "  网络: $BRIDGE"
    echo "  IP: $VM_IP"
    echo "  网关: $GATEWAY"
    echo "  DNS: $DNS"
    echo "  自动启动: $AUTO_START"
    echo ""
    
    read -p "确认创建？(y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        msg_error "用户取消"
    fi
}

# 下载 cloud-init 镜像
function download_image() {
    local url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    local file="/var/lib/vz/template/iso/debian-13-cloud.qcow2"
    
    if [ -f "$file" ]; then
        msg_ok "镜像已存在: $file"
        return 0
    fi
    
    msg_info "下载 Debian 13 cloud-init 镜像..."
    msg_info "URL: $url"
    
    if ! wget -q --show-progress -O "$file" "$url" 2>&1; then
        msg_error "镜像下载失败"
    fi
    
    if [ ! -s "$file" ]; then
        rm -f "$file"
        msg_error "下载的镜像文件无效"
    fi
    
    msg_ok "镜像下载完成"
}

# 创建 VM
function create_vm() {
    msg_info "创建 VM $VMID ($VM_NAME)..."
    
    # 删除已存在的 VM
    if qm status $VMID &>/dev/null; then
        msg_info "删除已存在的 VM $VMID..."
        qm stop $VMID &>/dev/null || true
        sleep 2
        qm destroy $VMID &>/dev/null || true
        sleep 2
    fi
    
    # 创建 VM
    local onboot_flag=""
    if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
        onboot_flag="-onboot 1"
    fi
    
    qm create $VMID \
        -name "$VM_NAME" \
        -cores $CPU_CORES \
        -memory $MEMORY \
        -net0 virtio,bridge=$BRIDGE \
        -agent 1 \
        -bios ovmf \
        -machine q35 \
        -ostype l26 \
        -scsihw virtio-scsi-pci \
        $onboot_flag \
        -serial0 socket \
        -vga serial0 \
        || msg_error "VM 创建失败"
    
    msg_ok "VM 创建成功"
}

# 配置磁盘
function setup_disk() {
    msg_info "配置磁盘..."
    
    local image_file="/var/lib/vz/template/iso/debian-13-cloud.qcow2"
    
    # 分配 EFI 磁盘
    pvesm alloc $STORAGE $VMID vm-${VMID}-disk-0 4M &>/dev/null
    
    # 导入 cloud-init 镜像
    msg_info "导入磁盘镜像..."
    qm importdisk $VMID "$image_file" $STORAGE &>/dev/null || msg_error "磁盘导入失败"
    
    # 配置磁盘
    qm set $VMID \
        -efidisk0 ${STORAGE}:vm-${VMID}-disk-0 \
        -scsi0 ${STORAGE}:vm-${VMID}-disk-1,size=${DISK_SIZE}G \
        -boot order=scsi0 \
        &>/dev/null || msg_error "磁盘配置失败"
    
    msg_ok "磁盘配置完成"
}

# 配置 Cloud-init
function setup_cloudinit() {
    msg_info "配置 Cloud-init..."
    
    # 添加 cloud-init 驱动器
    qm set $VMID -ide2 ${STORAGE}:cloudinit &>/dev/null
    
    # 配置网络
    qm set $VMID -ipconfig0 "ip=${VM_IP},gw=${GATEWAY}" &>/dev/null
    
    # 配置 DNS
    qm set $VMID -nameserver "$DNS" &>/dev/null
    
    # 配置用户
    qm set $VMID -ciuser root &>/dev/null
    qm set $VMID -cipassword "$ROOT_PASSWORD" &>/dev/null
    
    # 配置 SSH 密钥（如果提供）
    if [ -n "$SSH_KEY" ]; then
        qm set $VMID -sshkeys <(echo "$SSH_KEY") &>/dev/null
        msg_ok "SSH 公钥已配置"
    fi
    
    msg_ok "Cloud-init 配置完成"
}

# 启动 VM
function start_vm() {
    read -p "是否立即启动 VM？(y/n) [y]: " START_NOW
    START_NOW=${START_NOW:-y}
    
    if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
        msg_info "启动 VM..."
        qm start $VMID || msg_error "VM 启动失败"
        
        msg_info "等待 VM 就绪（最多 60 秒）..."
        local retry=0
        local ip_addr=$(echo $VM_IP | cut -d'/' -f1)
        
        while [ $retry -lt 60 ]; do
            if ping -c 1 -W 1 $ip_addr &>/dev/null; then
                msg_ok "VM 已就绪: $ip_addr"
                return 0
            fi
            retry=$((retry + 1))
            sleep 2
        done
        
        msg_error "VM 启动超时，请手动检查"
    fi
}

# 显示总结
function show_summary() {
    echo ""
    echo "════════════════════════════════════════"
    msg_ok "VM 创建完成！"
    echo "════════════════════════════════════════"
    echo ""
    echo "VM 信息："
    echo "  名称: $VM_NAME"
    echo "  VMID: $VMID"
    echo "  IP: $(echo $VM_IP | cut -d'/' -f1)"
    echo ""
    echo "连接方式："
    echo "  SSH: ssh root@$(echo $VM_IP | cut -d'/' -f1)"
    echo "  Proxmox 控制台: 在 PVE Web 界面中打开"
    echo ""
    echo "下一步："
    echo "  1. 等待 VM 完全启动（约 1-2 分钟）"
    echo "  2. SSH 登录进行配置"
    echo "  3. 安装所需服务"
    echo ""
}

# 主函数
function main() {
    check_root
    check_proxmox
    interactive_config
    download_image
    create_vm
    setup_disk
    setup_cloudinit
    start_vm
    show_summary
}

main

