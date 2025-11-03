# RouterOS 配置指南

针对 BoomDNS 环境的 RouterOS 配置方案

## 网络拓扑

```
互联网
  ↓
RouterOS (10.0.0.2/24)
  ↓
mihomo (10.0.0.4) ← 透明代理
  ↓
AdGuard Home (10.0.0.5) ← DNS 服务器
  ↓
局域网设备 (10.0.0.0/24)
```

---

## 基础配置

### 1. 网络接口

```bash
# 查看接口
/interface print

# 配置 WAN 口（通常是 ether1）
/ip address
add address=10.0.0.2/24 interface=ether1
add address=192.168.88.1/24 interface=bridge comment="LAN Bridge"

# 配置网关
/ip route
add gateway=10.0.0.1 comment="Default Gateway"
```

### 2. DNS 基础设置

```bash
# 设置 DNS 服务器为 AdGuard Home
/ip dns
set servers=10.0.0.5
set allow-remote-requests=yes
set cache-size=10240
```

---

## 方案一：DNS 劫持（推荐）

适合大多数家庭网络场景，简单有效。

### 配置步骤

```bash
# 1. 劫持所有 DNS 查询到 AdGuard Home
/ip firewall nat
add chain=dstnat action=dst-nat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 to-ports=53 \
    comment="DNS Hijack to AdGuard"

# 2. 防止 DNS 泄漏（可选但推荐）
add chain=dstnat action=dst-nat protocol=tcp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 to-ports=53 \
    comment="DNS Hijack TCP"
```

### 验证

```bash
# 在客户端测试
nslookup google.com

# 查看 RouterOS DNS 缓存
/ip dns cache print
```

---

## 方案二：DHCP + DNS

适合需要精细控制的场景。

### 配置步骤

```bash
# 1. 配置 DHCP 服务器
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

/ip dhcp-server
add name=dhcp1 interface=bridge address-pool=dhcp-pool disabled=no

/ip dhcp-server network
add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.5 \
    comment="DHCP Network with AdGuard DNS"

# 2. 添加 DNS 劫持（防止设备绕过）
/ip firewall nat
add chain=dstnat action=dst-nat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 to-addresses=10.0.0.5 \
    comment="Force DNS to AdGuard"
```

---

## 方案三：透明代理（高级）

适合需要在路由器层面实现代理的场景。

### 前提条件

- mihomo 已配置透明代理（redir-port 或 tproxy-port）
- 了解 RouterOS 策略路由

### 配置步骤

#### 1. 创建地址列表

```bash
# 国内 IP 段（示例，实际需要完整列表）
/ip firewall address-list
add list=cn_ip address=1.0.1.0/24 comment="CN IP"
add list=cn_ip address=1.0.2.0/23
# ... 更多国内 IP 段

# 内网地址
add list=local_ip address=10.0.0.0/24
add list=local_ip address=192.168.0.0/16
add list=local_ip address=172.16.0.0/12
```

#### 2. 标记流量

```bash
# 标记需要代理的流量（非国内、非内网）
/ip firewall mangle
add chain=prerouting action=mark-routing \
    dst-address-list=!cn_ip \
    dst-address-list=!local_ip \
    new-routing-mark=proxy_route passthrough=yes \
    comment="Mark foreign traffic"

# 排除 DNS 流量
add chain=prerouting action=accept \
    protocol=udp dst-port=53 \
    comment="Bypass DNS"
```

#### 3. 策略路由

```bash
# 将标记的流量路由到 mihomo
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.0.4 \
    routing-mark=proxy_route \
    comment="Route foreign traffic to mihomo"
```

#### 4. 配置 mihomo 透明代理

在 mihomo 的 `config.yaml` 中：

```yaml
# 启用透明代理
redir-port: 7892
tproxy-port: 7893

# 配置 iptables（在 mihomo VM 上执行）
# 见下方脚本
```

**mihomo VM 上的 iptables 规则：**

```bash
#!/bin/bash
# 保存为 /etc/mihomo/tproxy-setup.sh

# 清理旧规则
iptables -t nat -F
iptables -t mangle -F

# 接受本地流量
iptables -t nat -A PREROUTING -d 10.0.0.0/24 -j RETURN
iptables -t nat -A PREROUTING -d 192.168.0.0/16 -j RETURN

# 重定向 TCP 流量到 mihomo redir-port
iptables -t nat -A PREROUTING -p tcp -j REDIRECT --to-ports 7892

# TProxy 处理 UDP
ip rule add fwmark 1 table 100
ip route add local 0.0.0.0/0 dev lo table 100
iptables -t mangle -A PREROUTING -p udp -j TPROXY \
    --on-port 7893 --tproxy-mark 1
```

---

## 防火墙规则

### 基础安全规则

```bash
# 允许建立的连接
/ip firewall filter
add chain=input action=accept connection-state=established,related \
    comment="Accept established"

# 允许本地连接
add chain=input action=accept src-address=10.0.0.0/24 \
    comment="Accept from LAN"

# 允许 ICMP
add chain=input action=accept protocol=icmp \
    comment="Accept ICMP"

# 允许必要服务
add chain=input action=accept protocol=tcp dst-port=22 \
    comment="SSH"
add chain=input action=accept protocol=tcp dst-port=8291 \
    comment="Winbox"

# 拒绝其他入站流量
add chain=input action=drop comment="Drop all other"
```

### 访问控制

```bash
# 保护 AdGuard Home 和 mihomo
/ip firewall filter
add chain=forward action=accept dst-address=10.0.0.4 \
    src-address=10.0.0.0/24 comment="Allow LAN to mihomo"
add chain=forward action=accept dst-address=10.0.0.5 \
    src-address=10.0.0.0/24 comment="Allow LAN to AdGuard"
add chain=forward action=drop dst-address=10.0.0.4-10.0.0.5 \
    comment="Block external access"
```

---

## 性能优化

### 1. FastTrack（硬件加速）

```bash
# 加速已建立的连接
/ip firewall filter
add chain=forward action=fasttrack-connection \
    connection-state=established,related \
    comment="FastTrack"
add chain=forward action=accept \
    connection-state=established,related
```

### 2. Connection Tracking

```bash
# 优化连接跟踪
/ip firewall connection tracking
set enabled=yes
set tcp-established-timeout=1d
set tcp-close-timeout=10s
set udp-timeout=10s
```

### 3. DNS 缓存

```bash
# 增大 DNS 缓存
/ip dns
set cache-size=10240
set cache-max-ttl=1d
```

---

## 访客网络（可选）

隔离访客流量，提高安全性。

```bash
# 1. 创建访客 VLAN
/interface vlan
add name=guest-vlan vlan-id=99 interface=bridge

# 2. 分配 IP
/ip address
add address=10.0.99.1/24 interface=guest-vlan

# 3. 配置访客 DHCP
/ip pool
add name=guest-pool ranges=10.0.99.100-10.0.99.200

/ip dhcp-server
add name=guest-dhcp interface=guest-vlan address-pool=guest-pool

/ip dhcp-server network
add address=10.0.99.0/24 gateway=10.0.99.1 dns-server=10.0.0.5

# 4. 防火墙隔离
/ip firewall filter
add chain=forward action=drop src-address=10.0.99.0/24 \
    dst-address=10.0.0.0/24 comment="Block guest to LAN"
add chain=forward action=accept src-address=10.0.99.0/24 \
    comment="Allow guest to internet"
```

---

## 故障排查

### DNS 问题

```bash
# 检查 DNS 设置
/ip dns print

# 查看 DNS 缓存
/ip dns cache print

# 测试 DNS 解析
/tool fetch url=http://google.com
```

### 防火墙问题

```bash
# 查看活动连接
/ip firewall connection print

# 查看 NAT 规则
/ip firewall nat print

# 查看 mangle 规则
/ip firewall mangle print

# 查看日志
/log print where topics~"firewall"
```

### 路由问题

```bash
# 查看路由表
/ip route print

# 查看策略路由
/ip route print where routing-mark=proxy_route

# 追踪路由
/tool traceroute 8.8.8.8
```

---

## 备份与恢复

### 备份配置

```bash
# 导出配置
/export file=router-config

# 下载到本地
/tool fetch address=10.0.0.100 src-path=router-config.rsc \
    dst-path=/backup/router-config.rsc mode=ftp
```

### 恢复配置

```bash
# 导入配置
/import file=router-config.rsc
```

---

## 监控与维护

### 查看系统状态

```bash
# CPU 和内存
/system resource print

# 网络流量
/interface monitor-traffic ether1

# 连接数
/ip firewall connection print count-only
```

### 定期维护

1. **每月检查**：
   - 固件更新
   - 配置备份
   - 日志审查

2. **每周检查**：
   - DNS 缓存清理
   - 连接数监控

```bash
# 清理 DNS 缓存
/ip dns cache flush

# 查看连接数
/ip firewall connection print count-only
```

---

## 完整配置示例

一个完整的 RouterOS 配置（基于方案一）：

```bash
# 1. 基础网络
/ip address
add address=10.0.0.2/24 interface=ether1
add address=192.168.88.1/24 interface=bridge

/ip route
add gateway=10.0.0.1

# 2. DNS
/ip dns
set servers=10.0.0.5
set allow-remote-requests=yes
set cache-size=10240

# 3. DHCP
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

/ip dhcp-server
add name=dhcp1 interface=bridge address-pool=dhcp-pool

/ip dhcp-server network
add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.5

# 4. DNS 劫持
/ip firewall nat
add chain=dstnat action=dst-nat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 to-addresses=10.0.0.5

# 5. 防火墙
/ip firewall filter
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=10.0.0.0/24
add chain=input action=accept protocol=icmp
add chain=input action=drop

add chain=forward action=fasttrack-connection \
    connection-state=established,related
add chain=forward action=accept connection-state=established,related

# 6. NAT
add chain=srcnat action=masquerade out-interface=ether1
```

---

## 常见问题

**Q: 如何确认 DNS 劫持生效？**

在客户端手动设置 DNS 为 `8.8.8.8`，然后测试解析，查询仍应通过 AdGuard Home。

**Q: mihomo 和 AdGuard Home 谁在前？**

流量顺序：客户端 → RouterOS → mihomo (代理) → AdGuard Home (DNS) → 互联网

**Q: 性能影响有多大？**

正确配置的 FastTrack 可以达到接近线速，DNS 缓存也能减少查询延迟。

---

## 参考资料

- [MikroTik Wiki](https://wiki.mikrotik.com/)
- [RouterOS Manual](https://help.mikrotik.com/docs/)

---

完成配置后，建议进行完整的网络测试，确保所有设备都能正常上网和过滤广告。

