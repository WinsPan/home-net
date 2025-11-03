#!/bin/bash

# 快速测试脚本 - 验证部署是否成功

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MIHOMO_IP="10.0.0.4"
ADGUARD_IP="10.0.0.5"

PASS=0
FAIL=0

function test_item() {
    local name=$1
    local cmd=$2
    
    echo -n "测试 ${name}... "
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗${NC}"
        FAIL=$((FAIL + 1))
    fi
}

echo "═══════════════════════════════════════"
echo "  BoomDNS 部署测试"
echo "═══════════════════════════════════════"
echo ""

# 网络测试
test_item "mihomo 网络" "ping -c 2 ${MIHOMO_IP}"
test_item "AdGuard 网络" "ping -c 2 ${ADGUARD_IP}"

# 服务测试
test_item "mihomo HTTP" "curl -s -o /dev/null -w '%{http_code}' http://${MIHOMO_IP}:9090 | grep -q 200"
test_item "AdGuard HTTP" "curl -s -o /dev/null -w '%{http_code}' http://${ADGUARD_IP}:3000 | grep -q 200"

# 代理测试
test_item "mihomo 代理" "curl -x http://${MIHOMO_IP}:7890 -s -o /dev/null -w '%{http_code}' https://www.google.com | grep -q 200"

# DNS 测试
test_item "AdGuard DNS" "nslookup google.com ${ADGUARD_IP}"

echo ""
echo "═══════════════════════════════════════"
echo -e "通过: ${GREEN}${PASS}${NC} | 失败: ${RED}${FAIL}${NC}"
echo "═══════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分测试失败${NC}"
    exit 1
fi

