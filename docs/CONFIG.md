# 配置指南

mihomo + AdGuard Home + RouterOS 完整配置

---

## 网络架构

```
客户端 → RouterOS → AdGuard → Internet
           ↓
        mihomo 代理
```

**IP:**
- RouterOS: 10.0.0.2
- mihomo: 10.0.0.3
- AdGuard Home: 10.0.0.4

---

## mihomo 配置

### 配置文件 `/etc/mihomo/config.yaml`

```yaml
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
external-controller: 0.0.0.0:9090

dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
  fallback:
    - https://dns.google/dns-query

# 订阅
proxy-providers:
  airport:
    type: http
    url: "你的订阅地址"
    interval: 86400
    path: ./proxies/airport.yaml

# 代理组
proxy-groups:
  - name: 节点选择
    type: select
    use: [airport]
  - name: 自动选择
    type: url-test
    use: [airport]

# 规则
rules:
  - DOMAIN-SUFFIX,cn,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,节点选择
```

**管理:** http://10.0.0.3:9090

---

## AdGuard Home 配置

### 初始化

访问 http://10.0.0.4:3000 完成设置

### DNS 设置

**上游 DNS:**
```
https://dns.alidns.com/dns-query
223.5.5.5
```

**过滤规则:**
```
https://anti-ad.net/easylist.txt
```

---

## RouterOS 配置

部署后会生成 `routeros-config.rsc`，执行：

```routeros
# DNS
/ip dns set servers=10.0.0.4,223.5.5.5

# DHCP
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.4

# DNS 劫持
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 action=dst-nat to-addresses=10.0.0.4

# 防火墙
/ip firewall filter add chain=input connection-state=established,related action=accept
/ip firewall filter add chain=input src-address=10.0.0.0/24 action=accept
/ip firewall filter add chain=input action=drop

# NAT
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

### 透明代理（可选）

```routeros
# 重定向到 mihomo
/ip firewall nat add chain=dstnat protocol=tcp src-address=10.0.0.0/24 action=dst-nat to-addresses=10.0.0.3 to-ports=7890
```

---

## 客户端代理

### Windows

```
设置 → 代理 → 手动
服务器: 10.0.0.3
端口: 7890
```

### macOS

```
系统偏好设置 → 网络 → 代理
HTTP 代理: 10.0.0.3:7890
```

### iOS/Android

```
WiFi → 代理 → 手动
服务器: 10.0.0.3
端口: 7890
```

---

## 测试

```bash
# 测试代理
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 测试 DNS
nslookup google.com 10.0.0.4
```

---

## 维护

```bash
# 重启服务
systemctl restart mihomo
systemctl restart AdGuardHome

# 查看日志
journalctl -u mihomo -f
journalctl -u AdGuardHome -f
```

---

完成！
