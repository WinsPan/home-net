# RouterOS (MikroTik) 配置指南

本文档详细说明如何在 RouterOS 主路由环境下配置 mihomo + AdGuard Home，实现全局代理和广告过滤。

## 📋 前提条件

- ✅ RouterOS 版本 6.x 或 7.x
- ✅ 已部署 mihomo 容器（例如：192.168.1.100）
- ✅ 已部署 AdGuard Home 容器（例如：192.168.1.101）
- ✅ 能够访问 RouterOS WebFig 或 WinBox

## 🎯 网络拓扑

```
互联网
  ↓
RouterOS (主路由)
  ↓
局域网设备 → AdGuard Home (192.168.1.101:53) → mihomo (192.168.1.100:53)
```

## 🚀 快速配置

### 方案一：DNS 劫持 + DHCP（推荐）

这是最简单且最常用的方案，通过 DHCP 分发 DNS，让所有设备自动使用 AdGuard Home。

#### 1. 配置 DHCP Server DNS

**通过 WinBox 配置**：

```
IP → DHCP Server → 双击你的 DHCP Server → Networks 标签
→ 双击网络 → DNS Servers 填入：192.168.1.101
```

**通过 Terminal 配置**：

```bash
# 查看当前 DHCP 网络配置
/ip dhcp-server network print

# 设置 DHCP 分发的 DNS 为 AdGuard Home
/ip dhcp-server network set 0 dns-server=192.168.1.101

# 如果需要备用 DNS（可选）
/ip dhcp-server network set 0 dns-server=192.168.1.101,192.168.1.100
```

#### 2. 配置路由器自身 DNS

**通过 Terminal 配置**：

```bash
# 设置路由器自身的 DNS
/ip dns set servers=192.168.1.101

# 启用 DNS 缓存（可选，建议启用）
/ip dns set allow-remote-requests=yes cache-size=2048KiB
```

#### 3. 验证配置

```bash
# 查看 DNS 设置
/ip dns print

# 查看 DHCP 网络设置
/ip dhcp-server network print detail

# 测试 DNS 解析
/tool fetch url=http://www.google.com mode=http
```

### 方案二：DNS 劫持（强制）

强制所有 DNS 请求都经过 AdGuard Home，即使设备手动设置了其他 DNS。

#### 1. 添加 NAT 规则

**通过 Terminal 配置**：

```bash
# 劫持所有 DNS 请求到 AdGuard Home
/ip firewall nat add \
    chain=dstnat \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=dst-nat \
    to-addresses=192.168.1.101 \
    to-ports=53 \
    comment="DNS Redirect to AdGuard Home"

# 创建本地 DNS 服务器地址列表（避免死循环）
/ip firewall address-list add \
    list=LOCAL_DNS \
    address=192.168.1.101 \
    comment="AdGuard Home"

/ip firewall address-list add \
    list=LOCAL_DNS \
    address=192.168.1.100 \
    comment="mihomo DNS"
```

**通过 WinBox 配置**：

```
IP → Firewall → NAT → 添加 (+)

General 标签:
  Chain: dstnat
  Protocol: udp (17)
  Dst. Port: 53

Advanced 标签:
  Dst. Address List: !LOCAL_DNS (注意感叹号)

Action 标签:
  Action: dst-nat
  To Addresses: 192.168.1.101
  To Ports: 53
  Comment: DNS Redirect to AdGuard Home
```

然后创建地址列表：

```
IP → Firewall → Address Lists → 添加 (+)

Name: LOCAL_DNS
Address: 192.168.1.101
Comment: AdGuard Home

再添加一个：
Name: LOCAL_DNS
Address: 192.168.1.100
Comment: mihomo DNS
```

### 方案三：透明代理（高级）

将 HTTP/HTTPS 流量也重定向到代理，实现真正的透明代理。

#### 1. 添加 Mangle 规则

```bash
# 标记需要代理的流量
/ip firewall mangle add \
    chain=prerouting \
    dst-address-list=!CN_IP \
    protocol=tcp \
    dst-port=80,443 \
    action=mark-routing \
    new-routing-mark=proxy_route \
    passthrough=yes \
    comment="Mark proxy traffic"
```

#### 2. 添加路由规则

```bash
# 创建路由表，将标记的流量发送到 mihomo
/ip route add \
    routing-mark=proxy_route \
    gateway=192.168.1.100 \
    comment="Route to mihomo proxy"
```

#### 3. 配置 mihomo 透明代理

在 mihomo 容器中，需要启用 TUN 模式或 TPROXY 模式。

mihomo 配置文件添加：

```yaml
tun:
  enable: true
  stack: system
  auto-route: true
  auto-detect-interface: true
```

**注意**：透明代理配置较复杂，建议有一定网络基础再尝试。

## 🔧 详细配置选项

### DNS 配置优化

#### 启用 DNS 缓存

```bash
# 设置 DNS 缓存大小
/ip dns set cache-size=4096KiB

# 设置 DNS 缓存最大生存时间
/ip dns set cache-max-ttl=1d

# 允许远程请求（让路由器作为 DNS 服务器）
/ip dns set allow-remote-requests=yes
```

#### 配置静态 DNS 记录

```bash
# 为容器添加静态 DNS 记录（方便记忆）
/ip dns static add \
    name=adguard.home \
    address=192.168.1.101 \
    comment="AdGuard Home"

/ip dns static add \
    name=proxy.home \
    address=192.168.1.100 \
    comment="mihomo Proxy"
```

### DHCP 配置优化

#### 为特定设备分配静态 IP

```bash
# 为 AdGuard Home 容器分配静态 IP（可选）
/ip dhcp-server lease add \
    address=192.168.1.101 \
    mac-address=XX:XX:XX:XX:XX:XX \
    server=defconf \
    comment="AdGuard Home - Static"

# 为 mihomo 容器分配静态 IP（可选）
/ip dhcp-server lease add \
    address=192.168.1.100 \
    mac-address=XX:XX:XX:XX:XX:XX \
    server=defconf \
    comment="mihomo Proxy - Static"
```

### 防火墙规则

#### 允许必要的端口

```bash
# 允许访问 AdGuard Home 管理界面（从 LAN）
/ip firewall filter add \
    chain=input \
    protocol=tcp \
    dst-port=3000 \
    src-address=192.168.1.0/24 \
    action=accept \
    comment="Allow AdGuard Home Web UI"

# 允许 DNS 查询到 AdGuard Home
/ip firewall filter add \
    chain=forward \
    protocol=udp \
    dst-address=192.168.1.101 \
    dst-port=53 \
    action=accept \
    comment="Allow DNS to AdGuard Home"

# 允许访问 mihomo 控制面板（可选）
/ip firewall filter add \
    chain=forward \
    protocol=tcp \
    dst-address=192.168.1.100 \
    dst-port=9090 \
    action=accept \
    comment="Allow mihomo Control Panel"
```

#### 防止 DNS 泄漏

```bash
# 阻止绕过 AdGuard Home 的直接 DNS 查询（除了白名单）
/ip firewall filter add \
    chain=forward \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=reject \
    reject-with=icmp-network-unreachable \
    comment="Block Direct DNS Queries"

# 同样阻止 TCP DNS（DoT）
/ip firewall filter add \
    chain=forward \
    protocol=tcp \
    dst-port=53,853 \
    dst-address-list=!LOCAL_DNS \
    action=reject \
    reject-with=tcp-reset \
    comment="Block Direct DNS over TCP"
```

## 🌐 中国 IP 白名单（可选）

如果使用透明代理方案，可以配置中国 IP 白名单，让国内流量直连。

### 导入中国 IP 列表

```bash
# 创建中国 IP 地址列表
/ip firewall address-list add list=CN_IP address=1.0.1.0/24 comment="China IP"
/ip firewall address-list add list=CN_IP address=1.0.2.0/23 comment="China IP"
# ... 更多 IP 段

# 或使用脚本自动导入
# 下载脚本: https://github.com/firehol/blocklist-ipsets
```

### 使用现成的脚本

创建脚本文件 `import-cn-ip.rsc`:

```bash
# 清除旧的中国 IP 列表
/ip firewall address-list remove [find list="CN_IP"]

# 从文件导入（需要先上传 cn_ip.txt 到路由器）
/tool fetch url="https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt" mode=https dst-path=cn_ip.txt

# 导入地址列表
:local content [/file get cn_ip.txt contents]
:foreach line in=$content do={
    /ip firewall address-list add list=CN_IP address=$line comment="China IP"
}
```

执行脚本：

```bash
/import file-name=import-cn-ip.rsc
```

## 📊 监控和日志

### 查看 DNS 缓存

```bash
# 查看 DNS 缓存内容
/ip dns cache print

# 清除 DNS 缓存
/ip dns cache flush
```

### 查看 DHCP 租约

```bash
# 查看当前 DHCP 租约
/ip dhcp-server lease print

# 查看特定设备
/ip dhcp-server lease print where address=192.168.1.101
```

### 查看防火墙规则匹配

```bash
# 查看 NAT 规则统计
/ip firewall nat print stats

# 查看过滤规则统计
/ip firewall filter print stats

# 实时监控连接
/ip firewall connection print where dst-address~"192.168.1.101"
```

### 查看日志

```bash
# 查看系统日志
/log print

# 查看特定主题日志
/log print where topics~"dns"

# 持续监控日志
/log print follow
```

## 🚨 故障排查

### 问题 1：设备无法上网

**检查步骤**：

1. 检查 DHCP 是否正确分发 DNS：
```bash
/ip dhcp-server lease print
```

2. 测试路由器自身的 DNS：
```bash
/tool fetch url=http://www.google.com mode=http
```

3. 检查到容器的连通性：
```bash
/ping 192.168.1.101 count=10
/ping 192.168.1.100 count=10
```

4. 检查防火墙规则：
```bash
/ip firewall filter print
/ip firewall nat print
```

### 问题 2：DNS 劫持不生效

**检查步骤**：

1. 确认 NAT 规则存在且启用：
```bash
/ip firewall nat print where chain=dstnat
```

2. 确认地址列表配置正确：
```bash
/ip firewall address-list print where list=LOCAL_DNS
```

3. 查看规则匹配次数：
```bash
/ip firewall nat print stats where chain=dstnat
```

### 问题 3：部分设备 DNS 不生效

**可能原因**：

1. 设备使用了硬编码 DNS（如 8.8.8.8）
2. 设备使用了 DoH/DoT

**解决方法**：

使用强制 DNS 劫持（方案二）：

```bash
# 确保 DNS 劫持规则在最前面
/ip firewall nat print
# 如果不在前面，使用 move 命令调整顺序
/ip firewall nat move [find comment="DNS Redirect to AdGuard Home"] 0
```

### 问题 4：容器 IP 变化

如果容器使用 DHCP，IP 可能会变化，导致配置失效。

**解决方法**：

1. **在 Proxmox 中配置静态 IP**（推荐）
2. **在 RouterOS DHCP 中绑定 MAC 地址**

```bash
# 查看当前租约
/ip dhcp-server lease print

# 转换为静态
/ip dhcp-server lease make-static [find address=192.168.1.101]
/ip dhcp-server lease make-static [find address=192.168.1.100]
```

## 🎨 高级配置

### 配置分流

为不同的设备配置不同的 DNS 策略。

#### 示例：儿童设备使用严格过滤

```bash
# 部署第二个 AdGuard Home 容器（严格模式）
# 例如 IP: 192.168.1.102

# 为特定 MAC 地址指定特殊 DNS
/ip dhcp-server lease add \
    mac-address=XX:XX:XX:XX:XX:XX \
    address=192.168.1.50 \
    server=defconf \
    use-src-mac=yes \
    comment="Child Device"

# 添加 NAT 规则，将该设备 DNS 重定向到严格过滤的 AdGuard
/ip firewall nat add \
    chain=dstnat \
    src-address=192.168.1.50 \
    protocol=udp \
    dst-port=53 \
    action=dst-nat \
    to-addresses=192.168.1.102 \
    to-ports=53 \
    comment="Child Device - Strict DNS"
```

### 配置访客网络

```bash
# 创建访客网络接口
/interface vlan add \
    name=vlan-guest \
    vlan-id=10 \
    interface=bridge

# 配置访客网络 IP
/ip address add \
    address=192.168.10.1/24 \
    interface=vlan-guest

# 创建访客网络 DHCP
/ip pool add \
    name=guest-pool \
    ranges=192.168.10.100-192.168.10.200

/ip dhcp-server add \
    name=guest-dhcp \
    interface=vlan-guest \
    address-pool=guest-pool

/ip dhcp-server network add \
    address=192.168.10.0/24 \
    gateway=192.168.10.1 \
    dns-server=192.168.1.101 \
    comment="Guest Network"

# 访客网络隔离规则
/ip firewall filter add \
    chain=forward \
    src-address=192.168.10.0/24 \
    dst-address=192.168.1.0/24 \
    action=drop \
    comment="Isolate Guest Network"

# 允许访客访问 DNS
/ip firewall filter add \
    chain=forward \
    src-address=192.168.10.0/24 \
    dst-address=192.168.1.101 \
    dst-port=53 \
    protocol=udp \
    action=accept \
    comment="Allow Guest DNS"
```

## 📋 完整配置模板

### 基础配置（复制粘贴使用）

```bash
# ========================================
# 基础 DNS + DHCP 配置
# ========================================

# 1. 设置路由器 DNS
/ip dns set servers=192.168.1.101
/ip dns set allow-remote-requests=yes cache-size=4096KiB

# 2. 设置 DHCP 分发 DNS
/ip dhcp-server network set [find] dns-server=192.168.1.101

# 3. 添加静态 DNS 记录
/ip dns static add name=adguard.home address=192.168.1.101 comment="AdGuard Home"
/ip dns static add name=proxy.home address=192.168.1.100 comment="mihomo Proxy"

# 4. 绑定容器 IP（替换 MAC 地址）
/ip dhcp-server lease add address=192.168.1.101 mac-address=XX:XX:XX:XX:XX:XX comment="AdGuard Home"
/ip dhcp-server lease add address=192.168.1.100 mac-address=XX:XX:XX:XX:XX:XX comment="mihomo Proxy"

# 完成！重新获取 DHCP 即可生效
```

### 强制 DNS 劫持配置

```bash
# ========================================
# 强制 DNS 劫持配置
# ========================================

# 1. 创建本地 DNS 白名单
/ip firewall address-list add list=LOCAL_DNS address=192.168.1.101 comment="AdGuard Home"
/ip firewall address-list add list=LOCAL_DNS address=192.168.1.100 comment="mihomo DNS"

# 2. 添加 DNS 劫持规则（UDP）
/ip firewall nat add \
    chain=dstnat \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=dst-nat \
    to-addresses=192.168.1.101 \
    to-ports=53 \
    comment="Force DNS to AdGuard Home"

# 3. 阻止绕过的 DNS 查询
/ip firewall filter add \
    chain=forward \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=reject \
    reject-with=icmp-network-unreachable \
    comment="Block Direct DNS"

# 完成！所有 DNS 请求都会被劫持
```

## 🔄 配置备份

### 备份配置

```bash
# 导出完整配置
/export file=ros-backup

# 下载备份文件
# 通过 WinBox: Files → 右键 ros-backup.rsc → Download
```

### 恢复配置

```bash
# 导入配置
/import file-name=ros-backup.rsc
```

## 📚 参考资源

- [MikroTik Wiki - DNS](https://wiki.mikrotik.com/wiki/Manual:IP/DNS)
- [MikroTik Wiki - DHCP Server](https://wiki.mikrotik.com/wiki/Manual:IP/DHCP_Server)
- [MikroTik Wiki - Firewall](https://wiki.mikrotik.com/wiki/Manual:IP/Firewall)
- [AdGuard Home 文档](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [mihomo 文档](https://wiki.metacubex.one/)

## 💡 最佳实践

1. **使用静态 IP**：为容器配置静态 IP，避免 IP 变化导致配置失效
2. **备份配置**：修改前务必备份 RouterOS 配置
3. **逐步配置**：先配置基础方案，测试通过后再添加高级功能
4. **监控日志**：定期查看路由器和容器日志
5. **文档记录**：记录所有配置修改，便于后续维护

## ⚠️ 注意事项

1. **RouterOS 版本差异**：不同版本命令可能略有不同，请参考官方文档
2. **性能考虑**：防火墙规则过多会影响性能，定期清理不用的规则
3. **安全性**：如果从 WAN 访问管理界面，注意设置强密码和防火墙规则
4. **测试环境**：重大配置修改建议先在测试环境验证

---

**配置完成后，您的网络将实现：**
- ✅ 全局 DNS 广告过滤（通过 AdGuard Home）
- ✅ 智能国内外分流（通过 mihomo）
- ✅ DNS 无污染无泄漏
- ✅ 所有设备自动生效

**享受干净、快速的网络体验！** 🚀

