#!/bin/bash

# mihomo 智能配置应用脚本
# 自动应用 Smart 策略配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

function msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function show_header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║        mihomo 智能配置应用工具                        ║
║                                                      ║
║    Smart 策略 + 多机场 + 动态规则                     ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
    echo ""
}

# 检查权限
function check_root() {
    if [ "$EUID" -ne 0 ]; then
        msg_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检查 mihomo 是否已安装
function check_mihomo() {
    if [ ! -f "/usr/local/bin/mihomo" ]; then
        msg_error "未检测到 mihomo！请先安装 mihomo"
        exit 1
    fi
    msg_ok "mihomo 已安装"
}

# 备份原配置
function backup_config() {
    msg_info "备份原配置文件..."
    
    if [ -f "/etc/mihomo/config.yaml" ]; then
        BACKUP_FILE="/etc/mihomo/config.yaml.backup-$(date +%Y%m%d-%H%M%S)"
        cp /etc/mihomo/config.yaml "$BACKUP_FILE"
        msg_ok "配置已备份到: $BACKUP_FILE"
    else
        msg_warn "未找到原配置文件"
    fi
}

# 下载智能配置模板
function download_smart_config() {
    msg_info "下载智能配置模板..."
    
    TEMP_CONFIG="/tmp/smart-config.yaml"
    
    # 从 GitHub 下载配置模板
    if curl -fsSL "https://raw.githubusercontent.com/WinsPan/home-net/main/docs/SMART-CONFIG.md" -o /tmp/smart-config.md; then
        # 提取 YAML 配置（从第一个 ```yaml 到最后一个 ```）
        sed -n '/```yaml/,/```/p' /tmp/smart-config.md | sed '1d;$d' > "$TEMP_CONFIG"
        msg_ok "配置模板下载完成"
    else
        msg_error "下载配置模板失败"
        exit 1
    fi
}

# 配置机场订阅
function config_subscriptions() {
    echo ""
    msg_info "配置机场订阅"
    echo ""
    
    read -p "请输入机场 1 订阅地址（必填）: " AIRPORT_1
    if [ -z "$AIRPORT_1" ]; then
        msg_error "机场 1 订阅地址不能为空"
        exit 1
    fi
    
    read -p "请输入机场 2 订阅地址（可选，回车跳过）: " AIRPORT_2
    read -p "请输入机场 3 订阅地址（可选，回车跳过）: " AIRPORT_3
    
    # 替换配置文件中的订阅地址
    sed -i "s|https://your-airport-1-subscription-url|${AIRPORT_1}|g" "$TEMP_CONFIG"
    
    if [ -n "$AIRPORT_2" ]; then
        sed -i "s|https://your-airport-2-subscription-url|${AIRPORT_2}|g" "$TEMP_CONFIG"
        msg_ok "已配置 2 个机场订阅"
    else
        # 删除 airport-2 相关配置
        sed -i '/airport-2:/,/url: http:\/\/www.gstatic.com\/generate_204/d' "$TEMP_CONFIG"
        msg_info "未配置机场 2，已移除相关配置"
    fi
    
    if [ -n "$AIRPORT_3" ]; then
        sed -i "s|https://your-airport-3-subscription-url|${AIRPORT_3}|g" "$TEMP_CONFIG"
        msg_ok "已配置 3 个机场订阅"
    else
        # 删除 airport-3 相关配置
        sed -i '/airport-3:/,/url: http:\/\/www.gstatic.com\/generate_204/d' "$TEMP_CONFIG"
        msg_info "未配置机场 3，已移除相关配置"
    fi
}

# 配置 API 密钥
function config_api_secret() {
    echo ""
    read -p "是否设置 API 密钥？(y/N): " SET_SECRET
    
    if [ "$SET_SECRET" = "y" ] || [ "$SET_SECRET" = "Y" ]; then
        # 生成随机密钥
        SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
        sed -i "s|secret: \"your-secret-here\"|secret: \"${SECRET}\"|g" "$TEMP_CONFIG"
        
        msg_ok "API 密钥已设置: $SECRET"
        msg_warn "请保存此密钥，访问 Web 界面时需要"
    else
        sed -i "s|secret: \"your-secret-here\"|secret: \"\"|g" "$TEMP_CONFIG"
        msg_info "未设置 API 密钥（不推荐）"
    fi
}

# 应用配置
function apply_config() {
    msg_info "应用新配置..."
    
    # 创建必要的目录
    mkdir -p /etc/mihomo/providers
    mkdir -p /etc/mihomo/ruleset
    
    # 复制配置文件
    cp "$TEMP_CONFIG" /etc/mihomo/config.yaml
    chmod 644 /etc/mihomo/config.yaml
    
    msg_ok "配置文件已应用"
}

# 验证配置
function verify_config() {
    msg_info "验证配置文件..."
    
    if mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml; then
        msg_ok "配置文件验证通过"
    else
        msg_error "配置文件验证失败！"
        msg_error "正在恢复备份..."
        
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            cp "$BACKUP_FILE" /etc/mihomo/config.yaml
            msg_ok "已恢复原配置"
        fi
        exit 1
    fi
}

# 重启服务
function restart_service() {
    msg_info "重启 mihomo 服务..."
    
    systemctl restart mihomo
    sleep 2
    
    if systemctl is-active --quiet mihomo; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败！"
        msg_error "查看日志: journalctl -u mihomo -n 50"
        exit 1
    fi
}

# 显示结果
function show_result() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          mihomo 智能配置应用完成！                    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}配置特性:${NC}"
    echo "  ✅ 💡 智能选择 - 自动选最快节点"
    echo "  ✅ ⚖️ 负载均衡 - 多节点分流"
    echo "  ✅ 🔄 故障转移 - 自动切换备用"
    echo "  ✅ 📊 动态规则 - 自动更新"
    echo ""
    echo -e "${GREEN}服务信息:${NC}"
    echo "  HTTP 代理: http://10.0.0.4:7890"
    echo "  SOCKS5 代理: socks5://10.0.0.4:7891"
    echo "  Web 管理: http://10.0.0.4:9090"
    
    if [ -n "$SECRET" ]; then
        echo "  API 密钥: $SECRET"
    fi
    
    echo ""
    echo -e "${BLUE}常用命令:${NC}"
    echo "  查看状态: systemctl status mihomo"
    echo "  查看日志: journalctl -u mihomo -f"
    echo "  重启服务: systemctl restart mihomo"
    echo ""
    echo -e "${BLUE}测试代理:${NC}"
    echo "  curl -x http://10.0.0.4:7890 https://www.google.com -I"
    echo ""
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 访问 http://10.0.0.4:9090 查看 Web 管理界面"
    echo "  2. 查看文档了解更多配置: docs/SMART-CONFIG.md"
    echo ""
}

# 主函数
function main() {
    show_header
    check_root
    check_mihomo
    
    echo ""
    msg_warn "此操作会替换当前的 mihomo 配置文件"
    read -p "是否继续？(y/N): " CONFIRM
    
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        msg_info "操作已取消"
        exit 0
    fi
    
    echo ""
    backup_config
    download_smart_config
    config_subscriptions
    config_api_secret
    apply_config
    verify_config
    restart_service
    show_result
    
    # 清理临时文件
    rm -f /tmp/smart-config.md "$TEMP_CONFIG"
    
    msg_ok "🎉 完成！"
}

# 运行主函数
main

