#!/usr/bin/env bash
# Clash 转 sing-box 转换服务安装脚本
# 在 sing-box VM 或独立 VM 上运行：curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/converter/install.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

function msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
function msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

function header() {
    clear
    cat <<"EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      Clash 转 sing-box 转换服务 - 快速部署              ║
║                                                          ║
║  支持：Clash 订阅转换 + HTTP API + 自动更新              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

function check_system() {
    msg_info "检查系统环境..."
    
    if [ "$EUID" -ne 0 ]; then
        msg_error "需要 root 权限运行（使用 sudo bash 或 root 用户）"
    fi
    
    if [ ! -f /etc/debian_version ]; then
        msg_error "仅支持 Debian 系统"
    fi
    
    msg_ok "系统检查通过"
}

function install_deps() {
    msg_info "安装依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl wget python3 python3-pip python3-venv &>/dev/null
    msg_ok "依赖安装完成"
}

function create_converter_service() {
    msg_info "创建转换服务..."
    
    mkdir -p /opt/clash-converter
    
    # 创建 Python 转换脚本
    cat > /opt/clash-converter/converter.py <<'PYTHON'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Clash 配置转 sing-box 配置转换服务
"""

import json
import yaml
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def clash_to_singbox(clash_config):
    """
    将 Clash 配置转换为 sing-box 配置
    """
    singbox_config = {
        "log": {
            "level": "info",
            "timestamp": True
        },
        "dns": {
            "servers": [
                {
                    "tag": "dns_proxy",
                    "address": "https://1.1.1.1/dns-query",
                    "detour": "proxy"
                },
                {
                    "tag": "dns_direct",
                    "address": "https://223.5.5.5/dns-query",
                    "detour": "direct"
                }
            ],
            "rules": [
                {
                    "geosite": "cn",
                    "server": "dns_direct"
                }
            ],
            "final": "dns_proxy"
        },
        "inbounds": [
            {
                "type": "mixed",
                "tag": "mixed-in",
                "listen": "0.0.0.0",
                "listen_port": 7890,
                "sniff": True
            }
        ],
        "outbounds": [],
        "route": {
            "rules": [
                {
                    "protocol": "dns",
                    "outbound": "dns-out"
                },
                {
                    "geosite": "cn",
                    "geoip": ["cn", "private"],
                    "outbound": "direct"
                },
                {
                    "geosite": "category-ads-all",
                    "outbound": "block"
                }
            ],
            "final": "proxy",
            "auto_detect_interface": True
        }
    }
    
    # 转换节点
    outbounds = []
    proxy_tags = []
    
    for proxy in clash_config.get('proxies', []):
        proxy_type = proxy.get('type', '').lower()
        outbound = {
            "tag": proxy.get('name'),
            "type": proxy_type
        }
        
        # 根据不同类型转换
        if proxy_type in ['ss', 'shadowsocks']:
            outbound.update({
                "server": proxy.get('server'),
                "server_port": proxy.get('port'),
                "method": proxy.get('cipher'),
                "password": proxy.get('password')
            })
        elif proxy_type in ['vmess']:
            outbound.update({
                "server": proxy.get('server'),
                "server_port": proxy.get('port'),
                "uuid": proxy.get('uuid'),
                "security": proxy.get('cipher', 'auto'),
                "alter_id": proxy.get('alterId', 0)
            })
            if proxy.get('tls'):
                outbound['tls'] = {
                    "enabled": True,
                    "server_name": proxy.get('servername', proxy.get('server'))
                }
        elif proxy_type in ['trojan']:
            outbound.update({
                "server": proxy.get('server'),
                "server_port": proxy.get('port'),
                "password": proxy.get('password')
            })
            if proxy.get('sni'):
                outbound['tls'] = {
                    "enabled": True,
                    "server_name": proxy.get('sni')
                }
        
        outbounds.append(outbound)
        proxy_tags.append(proxy.get('name'))
    
    # 添加代理组
    outbounds.insert(0, {
        "type": "selector",
        "tag": "proxy",
        "outbounds": ["auto"] + proxy_tags + ["direct"],
        "default": "auto"
    })
    
    outbounds.insert(1, {
        "type": "urltest",
        "tag": "auto",
        "outbounds": proxy_tags,
        "url": "https://www.gstatic.com/generate_204",
        "interval": "10m",
        "tolerance": 50
    })
    
    # 添加基础出站
    outbounds.extend([
        {"type": "direct", "tag": "direct"},
        {"type": "block", "tag": "block"},
        {"type": "dns", "tag": "dns-out"}
    ])
    
    singbox_config['outbounds'] = outbounds
    
    return singbox_config

class ConverterHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            # 解析 URL
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != '/convert':
                self.send_error(404, 'Not Found')
                return
            
            # 获取订阅 URL
            query = urllib.parse.parse_qs(parsed.query)
            if 'url' not in query:
                self.send_error(400, 'Missing url parameter')
                return
            
            subscription_url = query['url'][0]
            logger.info(f"Converting subscription: {subscription_url}")
            
            # 下载 Clash 配置
            with urllib.request.urlopen(subscription_url) as response:
                clash_yaml = response.read().decode('utf-8')
            
            # 解析 YAML
            clash_config = yaml.safe_load(clash_yaml)
            
            # 转换为 sing-box 配置
            singbox_config = clash_to_singbox(clash_config)
            
            # 返回 JSON
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(singbox_config, indent=2).encode())
            
            logger.info("Conversion successful")
            
        except Exception as e:
            logger.error(f"Conversion error: {e}")
            self.send_error(500, str(e))
    
    def log_message(self, format, *args):
        logger.info(format % args)

def main():
    port = 8080
    server = HTTPServer(('0.0.0.0', port), ConverterHandler)
    logger.info(f"Converter service started on port {port}")
    logger.info(f"Usage: http://localhost:{port}/convert?url=<clash_subscription_url>")
    server.serve_forever()

if __name__ == '__main__':
    main()
PYTHON
    
    chmod +x /opt/clash-converter/converter.py
    
    msg_ok "转换服务脚本创建完成"
}

function install_python_deps() {
    msg_info "安装 Python 依赖..."
    
    cd /opt/clash-converter
    
    # 创建虚拟环境
    python3 -m venv venv
    
    # 安装依赖
    ./venv/bin/pip install --quiet pyyaml
    
    msg_ok "Python 依赖安装完成"
}

function setup_service() {
    msg_info "配置 systemd 服务..."
    
    cat > /etc/systemd/system/clash-converter.service <<EOF
[Unit]
Description=Clash to sing-box Converter Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/clash-converter
ExecStart=/opt/clash-converter/venv/bin/python3 /opt/clash-converter/converter.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable clash-converter
    systemctl start clash-converter
    
    sleep 3
    
    if systemctl is-active --quiet clash-converter; then
        msg_ok "服务启动成功"
    else
        msg_error "服务启动失败，查看日志: journalctl -u clash-converter -n 50"
    fi
}

function show_summary() {
    local IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg_ok "Clash 转换服务安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 服务信息："
    echo "   IP 地址: ${IP}"
    echo "   转换 API: http://${IP}:8080/convert?url=<订阅地址>"
    echo ""
    echo "🔧 管理命令："
    echo "   查看状态: systemctl status clash-converter"
    echo "   重启服务: systemctl restart clash-converter"
    echo "   查看日志: journalctl -u clash-converter -f"
    echo "   停止服务: systemctl stop clash-converter"
    echo ""
    echo "🧪 测试转换："
    echo "   curl 'http://${IP}:8080/convert?url=<你的clash订阅>' | jq"
    echo ""
    echo "📝 使用示例："
    echo "   在 sing-box 安装时选择使用转换服务"
    echo "   转换服务会自动将 Clash 订阅转换为 sing-box 格式"
    echo ""
    echo "💡 下一步："
    echo "   1. 测试转换服务是否正常"
    echo "   2. 在 sing-box 安装时使用此服务"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function main() {
    header
    check_system
    install_deps
    create_converter_service
    install_python_deps
    setup_service
    show_summary
}

main

