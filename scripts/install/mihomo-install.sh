#!/usr/bin/env bash

# Copyright (c) 2024 BoomDNS
# Author: BoomDNS Contributors
# License: MIT
# https://github.com/yourusername/boomdns

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "安装依赖包"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y wget
$STD apt-get install -y unzip
msg_ok "依赖包安装完成"

msg_info "检测系统架构"
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

msg_info "下载 mihomo"
LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"
wget -q --show-progress -O /tmp/mihomo.gz "${DOWNLOAD_URL}"
msg_ok "mihomo 下载完成 (版本: ${LATEST_VERSION})"

msg_info "安装 mihomo"
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm -f /tmp/mihomo.gz
msg_ok "mihomo 安装完成"

msg_info "创建配置目录"
mkdir -p /etc/mihomo
mkdir -p /var/log/mihomo
msg_ok "配置目录创建完成"

msg_info "创建默认配置文件"
cat <<'EOF' > /etc/mihomo/config.yaml
# mihomo 配置文件
# 更多配置选项请参考: https://wiki.metacubex.one/

# 混合端口配置
mixed-port: 7890

# 允许局域网连接
allow-lan: true

# 绑定地址
bind-address: "*"

# 运行模式: rule / global / direct
mode: rule

# 日志级别: info / warning / error / debug / silent
log-level: info

# 外部控制器
external-controller: 0.0.0.0:9090

# RESTful API 密钥
secret: ""

# DNS 配置
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

# 代理配置
proxies: []

# 代理组配置
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

# 规则配置
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
msg_ok "默认配置文件创建完成"

msg_info "创建 systemd 服务"
cat <<'EOF' > /etc/systemd/system/mihomo.service
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

msg_info "启用并启动 mihomo 服务"
systemctl daemon-reload
systemctl enable mihomo
systemctl start mihomo
msg_ok "mihomo 服务已启动"

msg_info "清理安装文件"
apt-get autoremove -y
apt-get autoclean -y
msg_ok "清理完成"

msg_info "获取容器信息"
IP=$(hostname -I | awk '{print $1}')
msg_ok "安装完成！"

echo -e "\n"
echo -e "==================== mihomo 信息 ===================="
echo -e "版本: ${LATEST_VERSION}"
echo -e "配置文件: /etc/mihomo/config.yaml"
echo -e "日志目录: /var/log/mihomo"
echo -e ""
echo -e "服务管理:"
echo -e "  启动服务: systemctl start mihomo"
echo -e "  停止服务: systemctl stop mihomo"
echo -e "  重启服务: systemctl restart mihomo"
echo -e "  查看状态: systemctl status mihomo"
echo -e "  查看日志: journalctl -u mihomo -f"
echo -e ""
echo -e "访问地址:"
echo -e "  容器 IP: ${IP}"
echo -e "  HTTP 代理: http://${IP}:7890"
echo -e "  SOCKS5 代理: socks5://${IP}:7890"
echo -e "  外部控制器: http://${IP}:9090"
echo -e ""
echo -e "下一步操作:"
echo -e "  1. 编辑配置文件: nano /etc/mihomo/config.yaml"
echo -e "  2. 添加您的代理节点到 proxies 部分"
echo -e "  3. 重启服务使配置生效: systemctl restart mihomo"
echo -e "  4. 推荐使用 Yacd 控制面板: http://yacd.metacubex.one"
echo -e "====================================================="
echo -e "\n"

