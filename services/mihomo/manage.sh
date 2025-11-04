#!/usr/bin/env bash
# mihomo 管理脚本 - 完整功能

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
║      mihomo 管理工具                 ║
╚══════════════════════════════════════╝
EOF
    echo ""
}

function show_status() {
    header
    echo "【服务状态】"
    echo ""
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "mihomo 服务运行中"
    else
        msg_error "mihomo 服务已停止"
    fi
    
    echo ""
    systemctl status mihomo --no-pager -l
    
    echo ""
    read -p "按回车继续..."
}

function update_subscription() {
    header
    msg_info "更新订阅..."
    
    local sub_url=$(cat /etc/mihomo/.subscription 2>/dev/null)
    if [ -z "$sub_url" ]; then
        msg_error "未找到订阅地址"
        read -p "按回车继续..."
        return
    fi
    
    msg_info "订阅地址: $sub_url"
    
    if curl -fsSL -o /etc/mihomo/proxies/airport.yaml "$sub_url"; then
        msg_ok "订阅更新成功"
        systemctl restart mihomo
        msg_ok "服务已重启"
    else
        msg_error "订阅更新失败"
    fi
    
    echo ""
    read -p "按回车继续..."
}

function change_subscription() {
    header
    echo "【修改订阅】"
    echo ""
    
    local old_sub=$(cat /etc/mihomo/.subscription 2>/dev/null)
    if [ -n "$old_sub" ]; then
        echo "当前订阅: $old_sub"
        echo ""
    fi
    
    read -p "新订阅地址: " new_sub
    
    if [ -z "$new_sub" ]; then
        msg_warn "订阅地址不能为空"
        read -p "按回车继续..."
        return
    fi
    
    if [[ ! "$new_sub" =~ ^https?:// ]]; then
        msg_error "订阅地址格式错误"
        read -p "按回车继续..."
        return
    fi
    
    # 更新配置文件
    sed -i "s|url:.*|url: \"$new_sub\"|" /etc/mihomo/config.yaml
    echo "$new_sub" > /etc/mihomo/.subscription
    
    msg_ok "订阅地址已更新"
    
    # 立即更新订阅
    msg_info "正在拉取新订阅..."
    if curl -fsSL -o /etc/mihomo/proxies/airport.yaml "$new_sub"; then
        msg_ok "订阅更新成功"
        systemctl restart mihomo
        msg_ok "服务已重启"
    else
        msg_error "订阅更新失败，请检查地址是否正确"
    fi
    
    echo ""
    read -p "按回车继续..."
}

function setup_transparent_proxy() {
    header
    echo "【配置透明代理】"
    echo ""
    
    msg_warn "透明代理需要配置 iptables 规则"
    echo ""
    echo "选项:"
    echo "  1) 启用透明代理"
    echo "  2) 禁用透明代理"
    echo "  3) 查看当前状态"
    echo "  0) 返回"
    echo ""
    
    read -p "请选择: " choice
    
    case $choice in
        1)
            enable_transparent_proxy
            ;;
        2)
            disable_transparent_proxy
            ;;
        3)
            show_iptables_status
            ;;
        0)
            return
            ;;
        *)
            msg_error "无效选项"
            ;;
    esac
    
    echo ""
    read -p "按回车继续..."
}

function enable_transparent_proxy() {
    msg_info "启用透明代理..."
    
    # 创建 iptables 规则脚本
    cat > /etc/mihomo/tproxy.sh <<'EOF'
#!/bin/bash
# mihomo 透明代理规则

# 清理旧规则
iptables -t nat -D PREROUTING -p tcp -j MIHOMO 2>/dev/null
iptables -t nat -F MIHOMO 2>/dev/null
iptables -t nat -X MIHOMO 2>/dev/null

# 创建新链
iptables -t nat -N MIHOMO

# 跳过本地和保留地址
iptables -t nat -A MIHOMO -d 0.0.0.0/8 -j RETURN
iptables -t nat -A MIHOMO -d 10.0.0.0/8 -j RETURN
iptables -t nat -A MIHOMO -d 127.0.0.0/8 -j RETURN
iptables -t nat -A MIHOMO -d 169.254.0.0/16 -j RETURN
iptables -t nat -A MIHOMO -d 172.16.0.0/12 -j RETURN
iptables -t nat -A MIHOMO -d 192.168.0.0/16 -j RETURN
iptables -t nat -A MIHOMO -d 224.0.0.0/4 -j RETURN
iptables -t nat -A MIHOMO -d 240.0.0.0/4 -j RETURN

# 重定向到 mihomo
iptables -t nat -A MIHOMO -p tcp -j REDIRECT --to-ports 7890

# 应用规则
iptables -t nat -A PREROUTING -p tcp -j MIHOMO

echo "透明代理已启用"
EOF

    chmod +x /etc/mihomo/tproxy.sh
    bash /etc/mihomo/tproxy.sh
    
    # 创建 systemd 服务
    cat > /etc/systemd/system/mihomo-tproxy.service <<EOF
[Unit]
Description=mihomo Transparent Proxy
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/mihomo/tproxy.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mihomo-tproxy
    
    msg_ok "透明代理已启用"
}

function disable_transparent_proxy() {
    msg_info "禁用透明代理..."
    
    systemctl disable mihomo-tproxy 2>/dev/null
    systemctl stop mihomo-tproxy 2>/dev/null
    
    iptables -t nat -D PREROUTING -p tcp -j MIHOMO 2>/dev/null
    iptables -t nat -F MIHOMO 2>/dev/null
    iptables -t nat -X MIHOMO 2>/dev/null
    
    msg_ok "透明代理已禁用"
}

function show_iptables_status() {
    echo ""
    echo "【当前 iptables 规则】"
    echo ""
    iptables -t nat -L MIHOMO -n -v 2>/dev/null || echo "未配置透明代理"
}

function test_nodes() {
    header
    echo "【测试节点】"
    echo ""
    
    msg_info "测试代理连接..."
    
    local ip=$(hostname -I | awk '{print $1}')
    
    # 测试 HTTP 代理
    if curl -x http://${ip}:7890 -s -o /dev/null -w '%{http_code}' https://www.google.com | grep -q 200; then
        msg_ok "HTTP 代理正常"
    else
        msg_error "HTTP 代理测试失败"
    fi
    
    # 测试 SOCKS5 代理
    if curl -x socks5://${ip}:7891 -s -o /dev/null -w '%{http_code}' https://www.google.com | grep -q 200; then
        msg_ok "SOCKS5 代理正常"
    else
        msg_error "SOCKS5 代理测试失败"
    fi
    
    echo ""
    msg_info "当前外网 IP:"
    curl -x http://${ip}:7890 -s http://ip.sb
    
    echo ""
    read -p "按回车继续..."
}

function view_logs() {
    header
    echo "【查看日志】"
    echo ""
    echo "按 Ctrl+C 退出"
    echo ""
    sleep 2
    
    journalctl -u mihomo -f
}

function restart_service() {
    header
    msg_info "重启 mihomo 服务..."
    
    systemctl restart mihomo
    
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务重启成功"
    else
        msg_error "服务重启失败"
    fi
    
    echo ""
    read -p "按回车继续..."
}

function show_config() {
    header
    echo "【当前配置】"
    echo ""
    
    echo "订阅地址:"
    cat /etc/mihomo/.subscription 2>/dev/null || echo "  未配置"
    echo ""
    
    echo "配置文件: /etc/mihomo/config.yaml"
    echo ""
    
    read -p "是否查看完整配置？(y/n): " view
    if [[ "$view" =~ ^[Yy]$ ]]; then
        less /etc/mihomo/config.yaml
    fi
}

function main_menu() {
    while true; do
        header
        
        echo "【主菜单】"
        echo ""
        echo "  1) 查看状态"
        echo "  2) 修改订阅"
        echo "  3) 更新订阅"
        echo "  4) 配置透明代理"
        echo "  5) 测试节点"
        echo "  6) 查看日志"
        echo "  7) 重启服务"
        echo "  8) 查看配置"
        echo "  0) 退出"
        echo ""
        
        read -p "请选择: " choice
        
        case $choice in
            1) show_status ;;
            2) change_subscription ;;
            3) update_subscription ;;
            4) setup_transparent_proxy ;;
            5) test_nodes ;;
            6) view_logs ;;
            7) restart_service ;;
            8) show_config ;;
            0) 
                msg_ok "退出"
                exit 0
                ;;
            *)
                msg_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 检查是否安装了 mihomo
if ! command -v mihomo &>/dev/null; then
    msg_error "mihomo 未安装，请先运行安装脚本"
    exit 1
fi

if [ ! -f /etc/mihomo/config.yaml ]; then
    msg_error "mihomo 配置文件不存在"
    exit 1
fi

main_menu

