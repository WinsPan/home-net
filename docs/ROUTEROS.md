# RouterOS 配置指南

针对 BoomDNS 的 RouterOS 配置方案

---

## 网络拓扑

```
互联网 → RouterOS (10.0.0.2) → mihomo (10.0.0.4) → AdGuard Home (10.0.0.5) → 设备
```

---

## 快速配置

### 1. 基础网络

```bash
# 接口 IP
/ip address
add address=10.0.0.2/24 interface=ether1

# 网关
/ip route
add gateway=10.0.0.1
```

### 2. DNS（带容错）

```bash
# 多 DNS 配置（关键）
/ip dns
set servers=10.0.0.5,223.5.5.5,119.29.29.29
set allow-remote-requests=yes
set cache-size=10240
```

### 3. DHCP

```bash
# IP 池
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

# DHCP 服务
/ip dhcp-server
add name=dhcp1 interface=ether1 address-pool=dhcp-pool

# 网络配置
/ip dhcp-server network
add address=10.0.0.0/24 \
    gateway=10.0.0.2 \
    dns-server=10.0.0.5,223.5.5.5,119.29.29.29
```

### 4. DNS 劫持（可选）

```bash
# 强制 DNS 到 AdGuard
/ip firewall nat
add chain=dstnat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 \
    comment="DNS Hijack"
```

### 5. 健康检查（重要）

```bash
# 检查脚本
/system script
add name=check-adguard source={
    :local ip "10.0.0.5"
    :local result [/ping $ip count=2]
    
    :if ($result = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
        /log warning "AdGuard DOWN!"
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}

# 定时任务（每分钟）
/system scheduler
add name=check-schedule on-event=check-adguard interval=1m
```

---

## 防火墙

### 基础规则

```bash
/ip firewall filter

# INPUT 链
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=10.0.0.0/24
add chain=input action=accept protocol=icmp
add chain=input action=drop

# FORWARD 链
add chain=forward action=fasttrack-connection \
    connection-state=established,related
add chain=forward action=accept \
    connection-state=established,related
```

### NAT

```bash
/ip firewall nat
add chain=srcnat action=masquerade out-interface=ether1
```

---

## 访客网络（可选）

### 创建隔离网络

```bash
# VLAN
/interface vlan
add name=guest-vlan vlan-id=99 interface=ether1

# IP 地址
/ip address
add address=10.0.99.1/24 interface=guest-vlan

# DHCP
/ip pool
add name=guest-pool ranges=10.0.99.100-10.0.99.200

/ip dhcp-server
add name=guest-dhcp interface=guest-vlan address-pool=guest-pool

/ip dhcp-server network
add address=10.0.99.0/24 \
    gateway=10.0.99.1 \
    dns-server=10.0.0.5

# 隔离规则
/ip firewall filter
add chain=forward action=drop \
    src-address=10.0.99.0/24 \
    dst-address=10.0.0.0/24 \
    comment="Block guest to LAN"
```

---

## 性能优化

### Connection Tracking

```bash
/ip firewall connection tracking
set tcp-established-timeout=1d
set tcp-close-timeout=10s
set udp-timeout=10s
```

### DNS 缓存

```bash
/ip dns
set cache-size=10240
set cache-max-ttl=1d
```

---

## 故障排查

### DNS 问题

```bash
# 检查 DNS
/ip dns print

# 查看缓存
/ip dns cache print

# 测试解析
/tool fetch url=http://google.com
```

### 防火墙问题

```bash
# 查看连接
/ip firewall connection print

# 查看规则
/ip firewall nat print
/ip firewall filter print

# 查看日志
/log print where topics~"firewall"
```

---

## 备份与恢复

### 备份

```bash
# 导出配置
/export file=backup-config

# 系统备份
/system backup save name=backup-system
```

### 恢复

```bash
# 导入配置
/import file=backup-config.rsc
```

---

## 监控

### 系统状态

```bash
# 资源使用
/system resource print

# 网络流量
/interface monitor-traffic ether1

# 连接数
/ip firewall connection print count-only
```

---

## 完整配置示例

```bash
# 完整配置（复制粘贴）

# 1. 网络
/ip address
add address=10.0.0.2/24 interface=ether1

/ip route
add gateway=10.0.0.1

# 2. DNS
/ip dns
set servers=10.0.0.5,223.5.5.5,119.29.29.29
set allow-remote-requests=yes
set cache-size=10240

# 3. DHCP
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

/ip dhcp-server
add name=dhcp1 interface=ether1 address-pool=dhcp-pool

/ip dhcp-server network
add address=10.0.0.0/24 \
    gateway=10.0.0.2 \
    dns-server=10.0.0.5,223.5.5.5,119.29.29.29

# 4. DNS 劫持
/ip firewall nat
add chain=dstnat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 \
    comment="DNS Hijack"

add chain=srcnat action=masquerade out-interface=ether1

# 5. 防火墙
/ip firewall filter
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=10.0.0.0/24
add chain=input action=accept protocol=icmp
add chain=input action=drop

add chain=forward action=fasttrack-connection \
    connection-state=established,related
add chain=forward action=accept \
    connection-state=established,related

# 6. 健康检查
/system script
add name=check-adguard source={
    :if ([/ping 10.0.0.5 count=2] = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
        /log warning "AdGuard DOWN!"
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}

/system scheduler
add name=check-schedule on-event=check-adguard interval=1m
```

---

完成！RouterOS 配置已完成，支持容错和自动切换。
