#!/usr/bin/env bash
# Mihomo 安装脚本
# 在 VM 上运行：bash install-mihomo.sh
# 或在线运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-mihomo.sh | bash
# 调试模式：DEBUG=1 bash install-mihomo.sh
# 卸载：bash install-mihomo.sh --uninstall
# 重新安装：bash install-mihomo.sh --reinstall
# 注意：脚本使用 https://gh-proxy.com/ 加速 GitHub 资源下载

# 启用调试模式
[ "$DEBUG" = "1" ] && set -x

# 解析命令行参数
if [ "$1" = "--uninstall" ]; then
    MODE="uninstall"
elif [ "$1" = "--reinstall" ]; then
    MODE="reinstall"
else
    MODE="install"
fi

# GitHub 加速配置
GH_PROXY="https://gh-proxy.com/"

# GitHub 加速函数：将 GitHub URL 转换为加速链接
convert_github_url() {
    local url="$1"
    echo "${GH_PROXY}${url}"
}

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
    echo "  Mihomo 安装程序"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限，请使用: sudo bash install-mihomo.sh"
    fi
    msg_info "Root 权限检查通过"
}

check_system() {
    msg_info "检查系统..."
    
    if [ ! -f /etc/os-release ]; then
        msg_error "无法检测系统类型，需要 /etc/os-release 文件"
    fi
    
    # 读取系统信息
    . /etc/os-release
    msg_info "检测到系统: $PRETTY_NAME"
    
    # 检查是否是 Linux 系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        msg_warn "此脚本主要针对 Linux 系统设计"
    fi
    
    msg_ok "系统检查通过"
}

detect_arch() {
    local machine_arch=$(uname -m)
    msg_info "检测到架构: $machine_arch"
    
    case $machine_arch in
        x86_64) 
            ARCH="amd64"
            # 检测 CPU 指令集支持
            detect_cpu_features
            ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armv6l) ARCH="armv7" ;;
        *) msg_error "不支持的架构: $machine_arch" ;;
    esac
    
    msg_ok "架构: $ARCH"
}

# 检测 CPU 特性，确定使用哪个 amd64 版本
detect_cpu_features() {
    if [ "$ARCH" != "amd64" ]; then
        return
    fi
    
    msg_info "检测 CPU 指令集支持..."
    
    # 检查是否支持 AVX2 (v3 指令集)
    if grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
        ARCH_SUFFIX="v3"
        msg_ok "CPU 支持 AVX2 (v3)，使用高性能版本"
    # 检查是否支持 AVX (v2 指令集)
    elif grep -q " avx " /proc/cpuinfo 2>/dev/null || grep -q "^flags.* avx " /proc/cpuinfo 2>/dev/null; then
        ARCH_SUFFIX="v2"
        msg_ok "CPU 支持 AVX (v2)，使用 v2 版本"
    else
        ARCH_SUFFIX="compatible"
        msg_ok "CPU 不支持 AVX，使用兼容版本"
    fi
}

get_latest_version() {
    msg_info "获取最新版本..."
    
    local api_url="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
    local accelerated_url=$(convert_github_url "$api_url")
    
    msg_info "使用 GitHub 加速: $GH_PROXY"
    VERSION=$(curl -s "$accelerated_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        msg_error "无法获取最新版本"
    else
        msg_ok "最新版本: ${VERSION}"
    fi
}

install_deps() {
    msg_info "安装依赖..."
    
    # 检查是否有 apt-get (Debian/Ubuntu)
    if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        msg_info "更新软件包列表..."
        apt-get update -qq || msg_warn "apt-get update 失败，继续执行..."
        
        msg_info "安装系统依赖包..."
        apt-get install -y -qq curl wget gzip 2>&1 | grep -v "^$" || msg_warn "部分依赖包安装可能有警告，但继续执行..."
    # 检查是否有 yum (CentOS/RHEL)
    elif command -v yum &>/dev/null; then
        msg_info "安装系统依赖包..."
        yum install -y curl wget gzip 2>&1 | grep -v "^$" || msg_warn "部分依赖包安装可能有警告，但继续执行..."
    # 检查是否有 apk (Alpine)
    elif command -v apk &>/dev/null; then
        msg_info "安装系统依赖包..."
        apk add --no-cache curl wget gzip 2>&1 || msg_warn "部分依赖包安装可能有警告，但继续执行..."
    else
        msg_warn "未检测到包管理器，跳过依赖安装"
    fi
    
    msg_ok "依赖检查完成"
}

install_mihomo() {
    msg_info "下载 Mihomo..."
    
    # 根据架构和 CPU 特性确定下载文件名
    local filename=""
    if [ "$ARCH" = "amd64" ] && [ -n "$ARCH_SUFFIX" ]; then
        # amd64 架构，使用检测到的版本后缀
        filename="mihomo-linux-${ARCH}-${ARCH_SUFFIX}-${VERSION}.gz"
    else
        # 其他架构，使用标准格式
        filename="mihomo-linux-${ARCH}-${VERSION}.gz"
    fi
    
    # 尝试下载，如果失败则尝试其他兼容版本（仅 amd64）
    local download_success=false
    local try_versions=("$filename")
    
    if [ "$ARCH" = "amd64" ]; then
        # 如果当前是 v3，失败时尝试 v2 和 compatible
        if [ "$ARCH_SUFFIX" = "v3" ]; then
            try_versions+=("mihomo-linux-amd64-v2-${VERSION}.gz")
            try_versions+=("mihomo-linux-amd64-compatible-${VERSION}.gz")
        elif [ "$ARCH_SUFFIX" = "v2" ]; then
            # 如果当前是 v2，失败时尝试 compatible
            try_versions+=("mihomo-linux-amd64-compatible-${VERSION}.gz")
        fi
    fi
    
    for filename in "${try_versions[@]}"; do
        local original_url="https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/${filename}"
        local download_url=$(convert_github_url "$original_url")
        
        msg_info "尝试下载: $filename"
        msg_info "使用 GitHub 加速: $GH_PROXY"
        
        # 使用 wget 或 curl 下载
        if command -v wget &>/dev/null; then
            if [ -t 1 ]; then
                # 终端环境，显示进度
                wget --show-progress "$download_url" -O /tmp/mihomo.gz 2>&1
            else
                # 非终端环境，静默下载
                wget -q "$download_url" -O /tmp/mihomo.gz 2>&1
            fi
        else
            curl -fsSL "$download_url" -o /tmp/mihomo.gz 2>&1
        fi
        
        if [ $? -eq 0 ] && [ -f /tmp/mihomo.gz ] && [ -s /tmp/mihomo.gz ]; then
            download_success=true
            msg_ok "下载成功: $filename"
            break
        else
            msg_warn "下载失败: $filename，尝试下一个版本..."
            rm -f /tmp/mihomo.gz
        fi
    done
    
    if [ "$download_success" = false ]; then
        msg_error "所有版本下载失败，请检查网络连接和版本信息"
    fi
    
    msg_info "解压文件..."
    gunzip -c /tmp/mihomo.gz > /tmp/mihomo || msg_error "解压失败"
    rm -f /tmp/mihomo.gz
    
    if [ ! -f /tmp/mihomo ]; then
        msg_error "安装失败，mihomo 可执行文件不存在"
    fi
    
    msg_info "安装到 /usr/local/bin..."
    mv /tmp/mihomo /usr/local/bin/mihomo-bin
    chmod +x /usr/local/bin/mihomo-bin
    
    # 创建包装脚本，支持 menu 命令
    create_menu_script
    
    # 验证安装
    if ! /usr/local/bin/mihomo-bin version &>/dev/null; then
        msg_warn "版本检查失败，但文件已安装"
    else
        msg_ok "Mihomo 版本: $(/usr/local/bin/mihomo-bin version | head -n 1)"
    fi
    
    msg_ok "Mihomo 安装完成"
}

# 创建菜单脚本和包装脚本
create_menu_script() {
    msg_info "创建菜单脚本..."
    
    # 确保目录存在
    mkdir -p /usr/local/bin
    
    # 创建临时文件，然后移动（避免 heredoc 卡住）
    local temp_menu=$(mktemp)
    
    # 创建菜单脚本
    cat > "$temp_menu" <<'MENU_EOF'
#!/usr/bin/env bash
# Mihomo 管理菜单

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

show_menu() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Mihomo 管理菜单"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1) 查看服务状态"
    echo "  2) 启动服务"
    echo "  3) 停止服务"
    echo "  4) 重启服务"
    echo "  5) 查看实时日志"
    echo "  6) 查看最近日志"
    echo "  7) 验证配置文件"
    echo "  8) 重新加载配置"
    echo "  9) 编辑配置文件"
    echo " 10) 修改订阅链接"
    echo " 11) 查看版本信息"
    echo " 12) 打开 Dashboard"
    echo " 13) 重新安装"
    echo " 14) 卸载"
    echo "  0) 退出"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_service_status() {
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务运行中"
        systemctl status mihomo --no-pager -l
    else
        msg_warn "服务未运行"
        systemctl status mihomo --no-pager -l
    fi
}

start_service() {
    msg_info "启动服务..."
    systemctl start mihomo
    sleep 1
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败"
    fi
}

stop_service() {
    msg_info "停止服务..."
    systemctl stop mihomo
    sleep 1
    if ! systemctl is-active --quiet mihomo; then
        msg_ok "服务已停止"
    else
        msg_error "服务停止失败"
    fi
}

restart_service() {
    msg_info "重启服务..."
    systemctl restart mihomo
    sleep 2
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务重启成功"
    else
        msg_error "服务重启失败"
    fi
}

view_realtime_logs() {
    msg_info "查看实时日志（按 Ctrl+C 退出）..."
    journalctl -u mihomo -f
}

view_recent_logs() {
    msg_info "查看最近 50 条日志..."
    journalctl -u mihomo -n 50 --no-pager
}

validate_config() {
    msg_info "验证配置文件..."
    if /usr/local/bin/mihomo-bin -t -d /etc/mihomo; then
        msg_ok "配置文件验证通过"
    else
        msg_error "配置文件验证失败"
    fi
}

reload_config() {
    msg_info "重新加载配置..."
    if systemctl is-active --quiet mihomo; then
        systemctl restart mihomo
        sleep 2
        if systemctl is-active --quiet mihomo; then
            msg_ok "配置已重新加载"
        else
            msg_error "配置重新加载失败"
        fi
    else
        msg_warn "服务未运行，无法重新加载配置"
    fi
}

edit_config() {
    local editor="${EDITOR:-nano}"
    if ! command -v "$editor" &>/dev/null; then
        editor="vi"
    fi
    msg_info "使用 $editor 编辑配置文件..."
    "$editor" /etc/mihomo/config.yaml
}

edit_subscription() {
    if [ ! -f /etc/mihomo/config.yaml ]; then
        msg_error "配置文件不存在: /etc/mihomo/config.yaml"
        return 1
    fi
    
    msg_info "修改订阅链接..."
    echo ""
    
    # 显示当前的订阅配置
    msg_info "当前订阅配置："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -A 2 "proxy-providers:" /etc/mihomo/config.yaml | head -20
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 查找 proxy-providers 部分
    local providers_start=$(grep -n "^proxy-providers:" /etc/mihomo/config.yaml | cut -d: -f1)
    
    if [ -z "$providers_start" ]; then
        msg_error "未找到 proxy-providers 配置部分"
        return 1
    fi
    
    echo "请选择操作："
    echo "  1) 添加新订阅"
    echo "  2) 编辑现有订阅"
    echo "  3) 删除订阅"
    echo "  0) 取消"
    echo ""
    read -p "请选择 [0-3]: " action
    
    case $action in
        1)
            add_subscription
            ;;
        2)
            edit_existing_subscription
            ;;
        3)
            delete_subscription
            ;;
        0)
            msg_info "取消操作"
            return 0
            ;;
        *)
            msg_error "无效选择"
            return 1
            ;;
    esac
}

add_subscription() {
    echo ""
    msg_info "添加新订阅..."
    read -p "订阅名称（例如：优质服务商）: " sub_name
    if [ -z "$sub_name" ]; then
        msg_error "订阅名称不能为空"
        return 1
    fi
    
    read -p "订阅链接 URL: " sub_url
    if [ -z "$sub_url" ]; then
        msg_error "订阅链接不能为空"
        return 1
    fi
    
    # 检查订阅名称是否已存在
    if grep -q "^\s*${sub_name}:" /etc/mihomo/config.yaml; then
        msg_error "订阅名称已存在: $sub_name"
        return 1
    fi
    
    # 备份配置文件
    cp /etc/mihomo/config.yaml /etc/mihomo/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
    
    # 找到 proxy-providers 部分的最后一个订阅项
    local providers_start=$(grep -n "^proxy-providers:" /etc/mihomo/config.yaml | cut -d: -f1)
    local last_provider_line=$(awk -v start="$providers_start" 'NR > start && /^\s+[^#].*:/ && !/^[a-zA-Z]/ {line=NR} END {print line}' /etc/mihomo/config.yaml)
    
    if [ -z "$last_provider_line" ]; then
        # 如果没有找到，在 proxy-providers 后添加
        sed -i "/^proxy-providers:/a\  ${sub_name}: {<<: *BaseProvider, url: '${sub_url}'}" /etc/mihomo/config.yaml
    else
        # 在最后一个订阅后添加
        sed -i "${last_provider_line}a\  ${sub_name}: {<<: *BaseProvider, url: '${sub_url}'}" /etc/mihomo/config.yaml
    fi
    
    msg_ok "订阅已添加: $sub_name"
    msg_info "请重启服务使配置生效"
}

edit_existing_subscription() {
    echo ""
    msg_info "编辑现有订阅..."
    
    # 列出所有订阅
    local subscriptions=$(grep -A 100 "^proxy-providers:" /etc/mihomo/config.yaml | grep -E "^\s+[^#].*:" | sed 's/://g' | sed 's/^[[:space:]]*//' | head -20)
    
    if [ -z "$subscriptions" ]; then
        msg_error "未找到订阅配置"
        return 1
    fi
    
    echo "当前订阅列表："
    echo "$subscriptions" | nl
    echo ""
    read -p "请输入要编辑的订阅编号: " sub_num
    
    local sub_name=$(echo "$subscriptions" | sed -n "${sub_num}p")
    if [ -z "$sub_name" ]; then
        msg_error "无效的订阅编号"
        return 1
    fi
    
    echo ""
    msg_info "当前订阅: $sub_name"
    local current_url=$(grep -A 1 "^\s*${sub_name}:" /etc/mihomo/config.yaml | grep "url:" | sed "s/.*url: ['\"]\(.*\)['\"].*/\1/")
    echo "当前链接: $current_url"
    echo ""
    
    read -p "新订阅链接 URL: " new_url
    if [ -z "$new_url" ]; then
        msg_error "订阅链接不能为空"
        return 1
    fi
    
    # 备份配置文件
    cp /etc/mihomo/config.yaml /etc/mihomo/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
    
    # 替换 URL
    sed -i "/^\s*${sub_name}:/,/url:/s|url: ['\"].*['\"]|url: '${new_url}'|" /etc/mihomo/config.yaml
    
    msg_ok "订阅已更新: $sub_name"
    msg_info "请重启服务使配置生效"
}

delete_subscription() {
    echo ""
    msg_warn "删除订阅..."
    
    # 列出所有订阅
    local subscriptions=$(grep -A 100 "^proxy-providers:" /etc/mihomo/config.yaml | grep -E "^\s+[^#].*:" | sed 's/://g' | sed 's/^[[:space:]]*//' | head -20)
    
    if [ -z "$subscriptions" ]; then
        msg_error "未找到订阅配置"
        return 1
    fi
    
    echo "当前订阅列表："
    echo "$subscriptions" | nl
    echo ""
    read -p "请输入要删除的订阅编号: " sub_num
    
    local sub_name=$(echo "$subscriptions" | sed -n "${sub_num}p")
    if [ -z "$sub_name" ]; then
        msg_error "无效的订阅编号"
        return 1
    fi
    
    echo ""
    msg_warn "将删除订阅: $sub_name"
    read -p "确认删除？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        msg_info "取消删除"
        return 0
    fi
    
    # 备份配置文件
    cp /etc/mihomo/config.yaml /etc/mihomo/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
    
    # 删除订阅（包括下一行的配置）
    sed -i "/^\s*${sub_name}:/,/},$/d" /etc/mihomo/config.yaml
    
    msg_ok "订阅已删除: $sub_name"
    msg_info "请重启服务使配置生效"
}

show_version() {
    msg_info "Mihomo 版本信息："
    /usr/local/bin/mihomo-bin version
}

open_dashboard() {
    local IP=$(hostname -I | awk '{print $1}')
    msg_info "Dashboard 地址: http://${IP}:9090/ui"
    msg_info "或: http://127.0.0.1:9090/ui"
    
    if command -v xdg-open &>/dev/null; then
        xdg-open "http://127.0.0.1:9090/ui" 2>/dev/null
    elif command -v open &>/dev/null; then
        open "http://127.0.0.1:9090/ui" 2>/dev/null
    else
        msg_info "请在浏览器中打开上述地址"
    fi
}

uninstall_mihomo() {
    msg_warn "此操作将卸载 Mihomo，包括："
    echo "  - 停止并删除服务"
    echo "  - 删除可执行文件"
    echo "  - 删除菜单脚本"
    echo "  - 配置文件将保留在 /etc/mihomo/"
    echo ""
    read -p "确认卸载？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        msg_info "取消卸载"
        return
    fi
    
    msg_info "开始卸载..."
    
    # 停止服务
    if systemctl is-active --quiet mihomo 2>/dev/null; then
        msg_info "停止服务..."
        systemctl stop mihomo
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet mihomo 2>/dev/null; then
        msg_info "禁用服务..."
        systemctl disable mihomo
    fi
    
    # 删除服务文件
    if [ -f /etc/systemd/system/mihomo.service ]; then
        msg_info "删除服务文件..."
        rm -f /etc/systemd/system/mihomo.service
        systemctl daemon-reload
    fi
    
    # 删除可执行文件
    if [ -f /usr/local/bin/mihomo-bin ]; then
        msg_info "删除可执行文件..."
        rm -f /usr/local/bin/mihomo-bin
    fi
    
    # 删除包装脚本和菜单脚本
    if [ -f /usr/local/bin/mihomo ]; then
        msg_info "删除包装脚本..."
        rm -f /usr/local/bin/mihomo
    fi
    
    if [ -f /usr/local/bin/mihomo-menu ]; then
        msg_info "删除菜单脚本..."
        rm -f /usr/local/bin/mihomo-menu
    fi
    
    msg_ok "卸载完成"
    msg_info "配置文件已保留在 /etc/mihomo/，如需完全删除请手动执行："
    echo "  rm -rf /etc/mihomo"
}

reinstall_mihomo() {
    msg_warn "此操作将重新安装 Mihomo："
    echo "  - 先卸载当前版本"
    echo "  - 然后重新下载并安装最新版本"
    echo "  - 配置文件将保留"
    echo ""
    read -p "确认重新安装？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        msg_info "取消重新安装"
        return
    fi
    
    # 先卸载（不提示确认）
    msg_info "开始卸载..."
    
    if systemctl is-active --quiet mihomo 2>/dev/null; then
        systemctl stop mihomo
    fi
    
    if systemctl is-enabled --quiet mihomo 2>/dev/null; then
        systemctl disable mihomo
    fi
    
    [ -f /etc/systemd/system/mihomo.service ] && rm -f /etc/systemd/system/mihomo.service && systemctl daemon-reload
    [ -f /usr/local/bin/mihomo-bin ] && rm -f /usr/local/bin/mihomo-bin
    [ -f /usr/local/bin/mihomo ] && rm -f /usr/local/bin/mihomo
    [ -f /usr/local/bin/mihomo-menu ] && rm -f /usr/local/bin/mihomo-menu
    
    msg_ok "卸载完成"
    echo ""
    msg_info "请运行安装脚本完成重新安装："
    echo "  bash install-mihomo.sh"
    echo ""
    msg_info "或退出菜单后运行："
    echo "  bash install-mihomo.sh --reinstall"
}

main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-14]: " choice
        echo ""
        
        case $choice in
            1)
                check_service_status
                ;;
            2)
                start_service
                ;;
            3)
                stop_service
                ;;
            4)
                restart_service
                ;;
            5)
                view_realtime_logs
                ;;
            6)
                view_recent_logs
                ;;
            7)
                validate_config
                ;;
            8)
                reload_config
                ;;
            9)
                edit_config
                ;;
            10)
                edit_subscription
                ;;
            11)
                show_version
                ;;
            12)
                open_dashboard
                ;;
            13)
                reinstall_mihomo
                ;;
            14)
                uninstall_mihomo
                ;;
            0)
                msg_info "退出菜单"
                exit 0
                ;;
            *)
                msg_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 键继续..."
    done
}

main
MENU_EOF
    
    # 移动临时文件到目标位置
    mv "$temp_menu" /usr/local/bin/mihomo-menu
    chmod +x /usr/local/bin/mihomo-menu
    
    # 创建包装脚本，支持 mihomo menu 命令
    local temp_wrapper=$(mktemp)
    cat > "$temp_wrapper" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Mihomo 包装脚本，支持 menu 子命令

if [ "$1" = "menu" ]; then
    exec /usr/local/bin/mihomo-menu
else
    exec /usr/local/bin/mihomo-bin "$@"
fi
WRAPPER_EOF
    
    # 移动临时文件到目标位置
    mv "$temp_wrapper" /usr/local/bin/mihomo
    chmod +x /usr/local/bin/mihomo
    
    msg_ok "菜单脚本已创建"
}

setup_config() {
    msg_info "配置目录..."
    
    # 创建配置目录
    mkdir -p /etc/mihomo
    
    # 如果配置文件不存在，从 GitHub 下载 MihomoPro 配置
    if [ ! -f /etc/mihomo/config.yaml ]; then
        msg_info "下载 MihomoPro 配置文件..."
        
        local original_url="https://raw.githubusercontent.com/666OS/YYDS/main/mihomo/config/MihomoPro.yaml"
        local download_url=$(convert_github_url "$original_url")
        
        msg_info "使用 GitHub 加速: $GH_PROXY"
        
        # 使用 wget 或 curl 下载
        if command -v wget &>/dev/null; then
            if [ -t 1 ]; then
                wget --show-progress "$download_url" -O /etc/mihomo/config.yaml
            else
                wget -q "$download_url" -O /etc/mihomo/config.yaml
            fi
        else
            curl -fsSL "$download_url" -o /etc/mihomo/config.yaml
        fi
        
        if [ $? -ne 0 ] || [ ! -f /etc/mihomo/config.yaml ] || [ ! -s /etc/mihomo/config.yaml ]; then
            msg_error "配置文件下载失败，请检查网络连接"
        fi
        
        msg_ok "配置文件已下载: /etc/mihomo/config.yaml"
        msg_warn "请根据实际情况修改配置文件，添加你的代理订阅链接"
    else
        msg_info "配置文件已存在，跳过下载"
    fi
    
    msg_ok "配置目录设置完成"
}

setup_service() {
    msg_info "配置 systemd 服务..."
    
    cat > /etc/systemd/system/mihomo.service <<'EOF'
[Unit]
Description=Mihomo Service
Documentation=https://github.com/MetaCubeX/mihomo
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mihomo-bin -d /etc/mihomo
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载 systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable mihomo
    
    msg_ok "systemd 服务配置完成"
}

start_service() {
    msg_info "验证配置文件..."
    
    # 验证配置文件格式
    if ! /usr/local/bin/mihomo-bin -t -d /etc/mihomo &>/dev/null; then
        msg_warn "配置文件验证失败，但继续启动服务"
        msg_warn "请检查配置文件: /etc/mihomo/config.yaml"
    else
        msg_ok "配置文件验证通过"
    fi
    
    msg_info "启动服务..."
    
    systemctl start mihomo
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_warn "服务启动可能失败，查看日志: journalctl -u mihomo -n 50"
        msg_warn "请检查配置文件是否正确，特别是 proxy-providers 中的订阅链接"
    fi
}

show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 配置文件"
    echo "   /etc/mihomo/config.yaml"
    echo ""
    echo "🔧 管理命令"
    echo "   mihomo menu                  # 交互式管理菜单（推荐）"
    echo "   systemctl status mihomo      # 状态"
    echo "   systemctl start mihomo       # 启动"
    echo "   systemctl stop mihomo        # 停止"
    echo "   systemctl restart mihomo     # 重启"
    echo "   journalctl -u mihomo -f      # 日志"
    echo ""
    echo "⚙️  配置说明"
    echo "   1. 编辑配置文件: /etc/mihomo/config.yaml"
    echo "   2. 在 proxy-providers 部分添加你的代理订阅链接"
    echo "   3. 重启服务: systemctl restart mihomo"
    echo ""
    echo "🌐 默认端口"
    echo "   HTTP/HTTPS 代理: 7890"
    echo "   SOCKS5 代理: 7891"
    echo "   混合端口: 7890"
    echo "   API 端口: 9090"
    echo ""
    echo "📚 相关资源"
    echo "   GitHub: https://github.com/MetaCubeX/mihomo"
    echo "   文档: https://wiki.metacubex.one"
    echo "   Dashboard: http://127.0.0.1:9090/ui"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 卸载函数（用于主脚本）
uninstall_main() {
    header
    check_root
    
    msg_warn "此操作将卸载 Mihomo，包括："
    echo "  - 停止并删除服务"
    echo "  - 删除可执行文件"
    echo "  - 删除菜单脚本"
    echo "  - 配置文件将保留在 /etc/mihomo/"
    echo ""
    read -p "确认卸载？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        msg_info "取消卸载"
        exit 0
    fi
    
    msg_info "开始卸载..."
    
    # 停止服务
    if systemctl is-active --quiet mihomo 2>/dev/null; then
        msg_info "停止服务..."
        systemctl stop mihomo
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet mihomo 2>/dev/null; then
        msg_info "禁用服务..."
        systemctl disable mihomo
    fi
    
    # 删除服务文件
    if [ -f /etc/systemd/system/mihomo.service ]; then
        msg_info "删除服务文件..."
        rm -f /etc/systemd/system/mihomo.service
        systemctl daemon-reload
    fi
    
    # 删除可执行文件
    if [ -f /usr/local/bin/mihomo-bin ]; then
        msg_info "删除可执行文件..."
        rm -f /usr/local/bin/mihomo-bin
    fi
    
    # 删除包装脚本和菜单脚本
    if [ -f /usr/local/bin/mihomo ]; then
        msg_info "删除包装脚本..."
        rm -f /usr/local/bin/mihomo
    fi
    
    if [ -f /usr/local/bin/mihomo-menu ]; then
        msg_info "删除菜单脚本..."
        rm -f /usr/local/bin/mihomo-menu
    fi
    
    msg_ok "卸载完成"
    msg_info "配置文件已保留在 /etc/mihomo/，如需完全删除请手动执行："
    echo "  rm -rf /etc/mihomo"
}

# 重新安装函数（用于主脚本）
reinstall_main() {
    header
    check_root
    
    msg_warn "此操作将重新安装 Mihomo："
    echo "  - 先卸载当前版本"
    echo "  - 然后重新下载并安装最新版本"
    echo "  - 配置文件将保留"
    echo ""
    read -p "确认重新安装？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        msg_info "取消重新安装"
        exit 0
    fi
    
    # 先卸载（不提示确认）
    msg_info "开始卸载..."
    
    if systemctl is-active --quiet mihomo 2>/dev/null; then
        systemctl stop mihomo
    fi
    
    if systemctl is-enabled --quiet mihomo 2>/dev/null; then
        systemctl disable mihomo
    fi
    
    [ -f /etc/systemd/system/mihomo.service ] && rm -f /etc/systemd/system/mihomo.service && systemctl daemon-reload
    [ -f /usr/local/bin/mihomo-bin ] && rm -f /usr/local/bin/mihomo-bin
    [ -f /usr/local/bin/mihomo ] && rm -f /usr/local/bin/mihomo
    [ -f /usr/local/bin/mihomo-menu ] && rm -f /usr/local/bin/mihomo-menu
    
    msg_ok "卸载完成，开始重新安装..."
    echo ""
    
    # 继续执行安装流程
    MODE="install"
}

# 显示主菜单
show_main_menu() {
    header
    echo ""
    echo "请选择操作："
    echo ""
    echo "  1) 安装 Mihomo"
    echo "  2) 卸载 Mihomo"
    echo "  3) 重新安装 Mihomo"
    if [ -f /usr/local/bin/mihomo-menu ]; then
        echo "  4) 进入管理菜单"
    fi
    echo "  0) 退出"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 安装流程
install_flow() {
    # 显示标题
    header
    
    # 步骤 1: 检查权限
    msg_info "步骤 1/8: 检查权限..."
    check_root
    
    # 步骤 2: 检查系统
    msg_info "步骤 2/8: 检查系统..."
    check_system
    
    # 步骤 3: 检测架构
    msg_info "步骤 3/8: 检测架构..."
    detect_arch
    
    # 步骤 4: 获取版本
    msg_info "步骤 4/8: 获取版本..."
    get_latest_version
    
    # 步骤 5: 安装依赖
    msg_info "步骤 5/8: 安装依赖..."
    install_deps
    
    # 步骤 6: 安装 Mihomo
    msg_info "步骤 6/8: 安装 Mihomo..."
    install_mihomo
    
    # 步骤 7: 配置
    msg_info "步骤 7/8: 配置..."
    setup_config
    setup_service
    
    # 步骤 8: 启动服务
    msg_info "步骤 8/8: 启动服务..."
    start_service
    
    # 完成
    show_summary
}

main() {
    # 如果有命令行参数，直接执行对应操作
    if [ "$MODE" = "uninstall" ]; then
        uninstall_main
        exit 0
    elif [ "$MODE" = "reinstall" ]; then
        reinstall_main
        # 重新安装会继续执行安装流程
        install_flow
        show_summary
        exit 0
    fi
    
    # 没有参数时，显示主菜单
    while true; do
        show_main_menu
        
        # 检查权限（仅提示，不强制退出）
        if [ "$EUID" -ne 0 ]; then
            msg_warn "注意：部分操作需要 root 权限，请使用 sudo 运行脚本"
            echo ""
        fi
        
        local max_option=3
        if [ -f /usr/local/bin/mihomo-menu ]; then
            max_option=4
        fi
        
        # 从标准输入读取选择
        printf "请选择操作 [0-${max_option}]: "
        # 尝试从 /dev/tty 读取，如果失败则从标准输入读取
        if [ -t 0 ] && [ -c /dev/tty ]; then
            read -r choice < /dev/tty 2>/dev/null || read -r choice
        else
            read -r choice
        fi
        
        # 去除前后空白字符
        choice=$(echo "$choice" | tr -d '[:space:]')
        
        # 如果输入为空，重新显示菜单
        if [ -z "$choice" ]; then
            msg_warn "未输入选择，请重新输入"
            sleep 1
            continue
        fi
        
        echo ""
        
        case $choice in
            1)
                install_flow
                show_summary
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            2)
                uninstall_main
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            3)
                reinstall_main
                install_flow
                show_summary
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            4)
                if [ -f /usr/local/bin/mihomo-menu ]; then
                    /usr/local/bin/mihomo-menu
                else
                    msg_error "管理菜单不存在，请先安装 Mihomo"
                    echo ""
                    read -p "按 Enter 键返回主菜单..."
                fi
                ;;
            0)
                msg_info "退出"
                exit 0
                ;;
            *)
                if [ -n "$choice" ]; then
                    msg_error "无效选择: '$choice'，请重新输入"
                else
                    msg_error "未输入选择，请重新输入"
                fi
                echo ""
                if [ -t 0 ]; then
                    read -r -p "按 Enter 键继续..."
                else
                    sleep 2
                fi
                ;;
        esac
    done
}

# 捕获错误
set -E
trap 'msg_error "安装过程中发生错误，请检查上述输出"' ERR

main

