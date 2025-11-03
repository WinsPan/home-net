# 完整部署指南

## 环境要求

- Proxmox VE 8.0+
- 两台 Debian 12 虚拟机
- RouterOS 7.x

## IP 地址规划

| 服务 | IP 地址 | 说明 |
|------|---------|------|
| RouterOS | 10.0.0.2 | 网关路由器 |
| mihomo | 10.0.0.4 | 透明代理 |
| AdGuard Home | 10.0.0.5 | DNS 服务器 |

---

## 第一步：创建虚拟机

### 1. 创建 mihomo VM

在 Proxmox VE 控制台：

```bash
# 1. 创建 VM
VM ID: 100
Name: mihomo
OS: Debian 12
CPU: 2 cores
Memory: 2 GB
Disk: 20 GB
Network: vmbr0 (桥接到主网络)

# 2. 安装 Debian 12
# 使用最小化安装，只选择 SSH Server

# 3. 配置静态 IP
nano /etc/network/interfaces
```

编辑网络配置：

```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address 10.0.0.4/24
    gateway 10.0.0.2
    dns-nameservers 10.0.0.5
```

应用配置：

```bash
systemctl restart networking
```

### 2. 创建 AdGuard Home VM

```bash
VM ID: 101
Name: adguardhome
OS: Debian 12
CPU: 1 core
Memory: 1 GB
Disk: 10 GB
Network: vmbr0
```

配置静态 IP：

```
auto ens18
iface ens18 inet static
    address 10.0.0.5/24
    gateway 10.0.0.2
    dns-nameservers 8.8.8.8
```

---

## 第二步：安装服务

### 1. 安装 mihomo

SSH 连接到 mihomo VM (10.0.0.4)：

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh -o install-mihomo.sh

# 执行安装
chmod +x install-mihomo.sh
./install-mihomo.sh
```

**脚本会自动完成：**
- 下载最新版 mihomo
- 创建系统服务
- 配置默认配置文件
- 启动服务

### 2. 安装 AdGuard Home

SSH 连接到 AdGuard Home VM (10.0.0.5)：

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh -o install-adguardhome.sh

# 执行安装
chmod +x install-adguardhome.sh
./install-adguardhome.sh
```

**初始化配置：**

1. 浏览器访问：`http://10.0.0.5:3000`
2. 完成初始设置向导
3. 设置管理员账号密码

---

## 第三步：配置 mihomo

### 1. 编辑配置文件

```bash
nano /etc/mihomo/config.yaml
```

**基础配置模板：**

```yaml
# 端口配置
port: 7890                    # HTTP 代理端口
socks-port: 7891             # SOCKS5 代理端口
redir-port: 7892             # 透明代理端口
tproxy-port: 7893            # TProxy 端口
mixed-port: 7890             # 混合端口

# 允许局域网连接
allow-lan: true
bind-address: "*"

# 运行模式
mode: rule

# 日志级别
log-level: info

# DNS 配置
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  
  # 上游 DNS 服务器
  nameserver:
    - 10.0.0.5              # AdGuard Home
    
  fallback:
    - tls://8.8.8.8
    - tls://1.1.1.1
    
  # 国内域名使用 AdGuard
  nameserver-policy:
    "geosite:cn": [10.0.0.5]

# 代理提供者（订阅）
proxy-providers:
  my-proxy:
    type: http
    url: "你的订阅地址"
    interval: 86400
    path: ./proxies/my-proxy.yaml
    health-check:
      enable: true
      interval: 600
      url: http://www.gstatic.com/generate_204

# 代理组
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    use:
      - my-proxy
    
  - name: "🎯 国内流量"
    type: select
    proxies:
      - DIRECT
      
  - name: "🌍 国外流量"
    type: select
    proxies:
      - "🚀 节点选择"
      - DIRECT
      
  - name: "🛡️ 广告拦截"
    type: select
    proxies:
      - REJECT
      - DIRECT

# 规则
rules:
  # 局域网直连
  - GEOIP,private,DIRECT
  
  # 广告拦截
  - GEOSITE,category-ads-all,🛡️ 广告拦截
  
  # 国内流量
  - GEOSITE,cn,🎯 国内流量
  - GEOIP,cn,🎯 国内流量
  
  # 国外流量
  - GEOSITE,geolocation-!cn,🌍 国外流量
  
  # 默认
  - MATCH,🌍 国外流量
```

### 2. 验证配置

```bash
# 检查配置文件语法
mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml

# 重启服务
systemctl restart mihomo

# 查看状态
systemctl status mihomo
```

---

## 第四步：配置 AdGuard Home

### 1. 基础设置

访问管理界面：`http://10.0.0.5`

**上游 DNS 服务器：**
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
8.8.8.8
1.1.1.1
```

**Bootstrap DNS 服务器：**
```
223.5.5.5
119.29.29.29
```

### 2. 添加过滤规则

**DNS 黑名单：**
```
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt
https://anti-ad.net/easylist.txt
https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt
```

**DNS 白名单：**
```
https://raw.githubusercontent.com/privacy-protection-tools/dead-horse/master/anti-ad-white-list.txt
```

**应用规则：**
1. 进入 **过滤器** → **DNS 封锁清单**
2. 点击 **添加阻止列表** → **添加自定义列表**
3. 粘贴上述 URL，逐个添加
4. 点击 **保存并更新**

### 3. 高级设置

**查询日志配置：**
- 保留时间：24 小时（节省空间）
- 启用匿名化客户端 IP

**速率限制：**
- 限制每秒请求数：30（防止 DNS 洪水）

---

## 第五步：配置 RouterOS

### 方案一：基础 DNS 劫持（推荐）

```bash
# 1. 设置 DNS 服务器
/ip dns
set servers=10.0.0.5
set allow-remote-requests=yes

# 2. 强制所有 DNS 查询到 AdGuard Home
/ip firewall nat
add chain=dstnat action=dst-nat protocol=udp dst-port=53 \
    to-addresses=10.0.0.5 to-ports=53 comment="DNS Hijack"

# 3. 添加静态路由（可选，确保流量正确路由）
/ip route
add dst-address=10.0.0.4/32 gateway=10.0.0.2
add dst-address=10.0.0.5/32 gateway=10.0.0.2
```

### 方案二：透明代理（高级）

如果需要在 RouterOS 上配置透明代理：

```bash
# 1. 标记需要代理的流量
/ip firewall mangle
add chain=prerouting action=mark-routing \
    new-routing-mark=proxy_route passthrough=yes \
    dst-address-list=!cn_ip comment="Mark foreign traffic"

# 2. 路由代理流量到 mihomo
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.0.4 \
    routing-mark=proxy_route

# 3. 配置 mihomo 透明代理
# 参考 mihomo 配置的 redir-port 或 tproxy-port
```

---

## 第六步：测试验证

### 1. 测试 DNS 解析

```bash
# 在任意客户端测试
nslookup google.com 10.0.0.5
nslookup baidu.com 10.0.0.5
```

### 2. 测试广告过滤

访问：`http://testadblock.com`  
应该看到广告被拦截

### 3. 测试代理分流

```bash
# 查看当前 IP
curl ip.sb
curl myip.ipip.net

# 访问国内网站
curl -I baidu.com

# 访问国外网站
curl -I google.com
```

### 4. 查看服务状态

```bash
# mihomo VM
systemctl status mihomo
journalctl -u mihomo -f

# AdGuard Home VM
systemctl status AdGuardHome
```

---

## 维护管理

### 更新 mihomo

```bash
# 使用更新脚本
/opt/mihomo/update-mihomo.sh
```

### 更新 AdGuard Home

在 Web 界面：**设置** → **常规设置** → **检查更新**

### 备份配置

```bash
# 备份 mihomo 配置
cp /etc/mihomo/config.yaml /root/mihomo-config-backup.yaml

# 备份 AdGuard Home 配置
systemctl stop AdGuardHome
tar -czf /root/adguardhome-backup.tar.gz /opt/AdGuardHome
systemctl start AdGuardHome
```

### 查看日志

```bash
# mihomo
journalctl -u mihomo -n 50

# AdGuard Home
journalctl -u AdGuardHome -n 50

# RouterOS
/log print where topics~"dns|firewall"
```

---

## 故障排查

### DNS 无法解析

1. 检查 AdGuard Home 是否运行
2. 检查 RouterOS 的 DNS 设置
3. 检查防火墙规则

```bash
# 测试 DNS 连通性
ping 10.0.0.5
telnet 10.0.0.5 53
```

### 代理不工作

1. 检查 mihomo 状态
2. 验证配置文件语法
3. 查看订阅是否更新

```bash
# 查看 mihomo 日志
journalctl -u mihomo -f

# 手动测试代理
curl -x http://10.0.0.4:7890 google.com
```

### 广告未被拦截

1. 确认过滤规则已添加并更新
2. 清除浏览器缓存和 DNS 缓存
3. 查看 AdGuard Home 查询日志

---

## 性能优化

### mihomo 优化

```yaml
# 在 config.yaml 中添加
profile:
  store-selected: true        # 记住选择的节点
  store-fake-ip: true         # 持久化 fake-ip

# 开启进程控制
experimental:
  ignore-resolve-fail: true   # 忽略 DNS 解析失败
```

### AdGuard Home 优化

- 减少查询日志保留时间
- 启用并行 DNS 查询
- 使用 HTTPS DNS (DoH)

### RouterOS 优化

```bash
# 启用 Fasttrack (硬件加速)
/ip firewall filter
add chain=forward action=fasttrack-connection \
    connection-state=established,related comment="FastTrack"
```

---

## 完成！

现在你已经拥有一个完整的智能家庭网络：

✅ 自动分流：国内国外流量智能路由  
✅ 广告过滤：全网设备广告拦截  
✅ 高性能：硬件加速和优化配置

如有问题，请查看 GitHub Issues 或提交反馈。

