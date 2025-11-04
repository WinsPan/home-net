#!/usr/bin/env bash
# Sub-Store Docker 部署脚本
# 使用 Docker 运行 Sub-Store，轻量级，无需编译
# 调试：DEBUG=1 bash install-substore-docker.sh

[ "$DEBUG" = "1" ] && set -x

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

header() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sub-Store Docker 部署程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    [ "$EUID" -ne 0 ] && msg_error "需要 root 权限"
    msg_info "Root 权限检查通过"
}

check_system() {
    msg_info "检查系统..."
    [ ! -f /etc/os-release ] && msg_error "无法检测系统"
    
    . /etc/os-release
    msg_info "系统: $PRETTY_NAME"
    
    [[ "$ID" != "debian" ]] && [[ "$ID_LIKE" != *"debian"* ]] && msg_error "仅支持 Debian/Ubuntu"
    msg_ok "系统检查通过"
}

install_docker() {
    if command -v docker &>/dev/null; then
        msg_ok "Docker 已安装: $(docker --version)"
        setup_docker_mirror
        return
    fi
    
    msg_info "安装 Docker..."
    
    # 安装依赖
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    
    # 添加 Docker 官方 GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # 添加 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装 Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 配置国内镜像源
    setup_docker_mirror
    
    # 启动 Docker
    systemctl enable docker
    systemctl start docker
    
    msg_ok "Docker $(docker --version) 安装完成"
}

setup_docker_mirror() {
    msg_info "配置 Docker 国内镜像源..."
    
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://docker.1ms.run"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    # 重启 Docker 使配置生效
    if systemctl is-active --quiet docker; then
        systemctl restart docker
        msg_ok "Docker 镜像源配置完成"
    else
        msg_info "Docker 未运行，镜像源配置已保存"
    fi
}

deploy_substore() {
    msg_info "部署 Sub-Store..."
    
    # 创建数据目录
    mkdir -p /opt/sub-store
    
    # 生成随机 API 路径（安全性）
    local BACKEND_PATH=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
    
    # 停止旧容器（如果存在）
    docker stop sub-store 2>/dev/null || true
    docker rm sub-store 2>/dev/null || true
    
    # 运行 Sub-Store 容器
    docker run -d \
        --name sub-store \
        --restart always \
        -p 3001:3001 \
        -v /opt/sub-store:/opt/app/data \
        -e "SUB_STORE_BACKEND_API_HOST=0.0.0.0" \
        -e "SUB_STORE_BACKEND_API_PORT=3001" \
        -e "SUB_STORE_FRONTEND_BACKEND_PATH=/$BACKEND_PATH" \
        xream/sub-store || msg_error "容器启动失败"
    
    # 保存 BACKEND_PATH 到文件
    echo "$BACKEND_PATH" > /opt/sub-store/.backend_path
    chmod 600 /opt/sub-store/.backend_path
    
    msg_info "等待服务启动..."
    sleep 5
    
    # 检查容器状态
    if docker ps | grep -q sub-store; then
        msg_ok "Sub-Store 容器运行中"
        echo ""
        msg_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        msg_info "📋 重要信息（请保存）"
        msg_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  🌐 访问地址: http://10.0.0.5:3001"
        echo "  🔑 API 路径:  /$BACKEND_PATH"
        echo "  📁 数据目录:  /opt/sub-store"
        echo ""
        msg_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        msg_info "💡 提示："
        echo "  - API 路径已保存到: /opt/sub-store/.backend_path"
        echo "  - 查看路径: cat /opt/sub-store/.backend_path"
        echo "  - 查看日志: docker logs -f sub-store"
        echo ""
    else
        msg_error "容器启动失败，查看日志: docker logs sub-store"
    fi
}

setup_systemd() {
    msg_info "配置系统服务..."
    
    # 创建 systemd 服务（可选，Docker 已经有 restart 策略）
    cat > /etc/systemd/system/sub-store-docker.service <<'EOF'
[Unit]
Description=Sub-Store Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start sub-store
ExecStop=/usr/bin/docker stop sub-store
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sub-store-docker
    
    msg_ok "系统服务配置完成"
}

show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    local BACKEND_PATH=""
    if [[ -f /opt/sub-store/.backend_path ]]; then
        BACKEND_PATH=$(cat /opt/sub-store/.backend_path)
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "部署完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🌐 Web 管理界面"
    echo "   http://${IP}:3001"
    if [[ -n "$BACKEND_PATH" ]]; then
        echo ""
        echo "🔑 API 路径（重要！请保存）"
        echo "   /$BACKEND_PATH"
        echo "   💾 已保存到: /opt/sub-store/.backend_path"
    fi
    echo ""
    echo "📦 Docker 管理"
    echo "   docker ps                     # 查看容器"
    echo "   docker logs sub-store         # 查看日志"
    echo "   docker logs -f sub-store      # 实时日志"
    echo "   docker restart sub-store      # 重启容器"
    echo "   docker stop sub-store         # 停止容器"
    echo "   docker start sub-store        # 启动容器"
    echo ""
    echo "🔧 系统服务"
    echo "   systemctl status sub-store-docker"
    echo "   systemctl restart sub-store-docker"
    echo ""
    echo "📂 数据目录"
    echo "   /opt/sub-store"
    echo ""
    echo "💡 使用说明"
    echo "   1. 访问 Web UI: http://${IP}:3001"
    echo "   2. 添加订阅源（Clash/V2Ray/等）"
    echo "   3. 创建订阅集合"
    echo "   4. 选择输出格式: sing-box"
    echo "   5. 复制生成的订阅链接"
    echo "   6. 在 sing-box 中使用该链接"
    echo ""
    if [[ -n "$BACKEND_PATH" ]]; then
        echo "🔐 查看 API 路径"
        echo "   cat /opt/sub-store/.backend_path"
        echo ""
    fi
    echo "🔄 更新 Sub-Store"
    echo "   docker pull xream/sub-store"
    echo "   docker stop sub-store && docker rm sub-store"
    echo "   curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-substore-docker.sh | bash"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    header
    
    msg_info "步骤 1/4: 检查权限..."
    check_root
    
    msg_info "步骤 2/4: 检查系统..."
    check_system
    
    msg_info "步骤 3/4: 安装 Docker..."
    install_docker
    
    msg_info "步骤 4/4: 部署 Sub-Store..."
    deploy_substore
    setup_systemd
    
    show_summary
}

set -E
trap 'msg_error "部署失败，请查看上述输出"' ERR

main

