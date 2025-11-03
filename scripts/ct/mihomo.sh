#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# https://github.com/yourusername/boomdns

function header_info {
clear
cat <<"EOF"
    __  ____  __  ______  __  _______
   /  |/  / / / / / / __ \/  |/  / __ \
  / /|_/ / / /_/ / / / / / /|_/ / / / /
 / /  / / / __  / / /_/ / /  / / /_/ /
/_/  /_/ /_/ /_/  \____/_/  /_/\____/

EOF
}
header_info
echo -e "加载中..."
APP="mihomo"
var_disk="4"
var_cpu="2"
var_ram="1024"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /etc/mihomo ]]; then
  msg_error "未检测到 mihomo 安装!"
  exit
fi
msg_info "更新 mihomo"
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

LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"

systemctl stop mihomo
wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm -f /tmp/mihomo.gz
systemctl start mihomo
msg_ok "mihomo 已更新到版本: ${LATEST_VERSION}"
exit
}

start
build_container
description

msg_ok "完成"
msg_info "mihomo 容器创建成功"
msg_info "进入容器配置 mihomo:"
msg_info "1. 编辑配置文件: nano /etc/mihomo/config.yaml"
msg_info "2. 重启服务: systemctl restart mihomo"
msg_info "3. 查看状态: systemctl status mihomo"

