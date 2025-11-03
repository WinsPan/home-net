# 完整部署指南 - 基于实际IP规划

本文档基于您的实际网络环境提供完整的部署和配置方案。

## 🌐 网络规划

```
网络拓扑：

互联网
  ↓
RouterOS (10.0.0.2)
  ↓ 
交换机/网络
  ├── mihomo VM (10.0.0.4)       - Proxmox 虚拟机 Debian 系统
  └── AdGuard Home VM (10.0.0.5) - Proxmox 虚拟机 Debian 系统
```

### IP 地址分配

| 设备 | IP地址 | 功能 | 端口 |
|------|--------|------|------|
| RouterOS | 10.0.0.2 | 主路由 | - |
| mihomo VM | 10.0.0.4 | 智能代理 | 7890, 9090, 53 |
| AdGuard Home VM | 10.0.0.5 | 广告过滤 | 3000, 53 |

### 数据流向

```
客户端设备
  ↓ DNS: 10.0.0.5
AdGuard Home (10.0.0.5:53)
  ↓ 广告过滤 → 上游DNS: 10.0.0.4:53
mihomo (10.0.0.4:53)
  ↓ 智能分流
互联网 (国内直连/国外代理)
```

## 📋 准备工作

### 1. Proxmox VE 准备

确保 Proxmox VE 已正确安装并可以访问：
```
https://pve-ip:8006
```

### 2. 下载 Debian 12 ISO

在 Proxmox Web 界面：
```
本地存储 (local) → ISO 镜像 → 下载
URL: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso
```

或使用命令行：
```bash
cd /var/lib/vz/template/iso/
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso
```

## 🚀 部署步骤

### 第一步：创建 mihomo 虚拟机

#### 1.1 在 Proxmox 创建虚拟机

**通过 Web 界面**：

```
1. 点击右上角 "创建虚拟机"
2. 常规设置：
   - 节点：选择您的节点
   - VM ID：100（或其他可用ID）
   - 名称：mihomo

3. 操作系统：
   - ISO 镜像：选择 debian-12.7.0-amd64-netinst.iso

4. 系统：
   - 图形卡：默认
   - BIOS：默认（SeaBIOS）
   - SCSI 控制器：VirtIO SCSI

5. 磁盘：
   - 总线/设备：SCSI
   - 磁盘大小：16 GB
   - 缓存：默认

6. CPU：
   - 核心：2

7. 内存：
   - 内存：2048 MB

8. 网络：
   - 桥接：vmbr0
   - 模型：VirtIO (半虚拟化)

9. 确认并完成
```

**通过命令行**：

```bash
# 创建 mihomo 虚拟机
qm create 100 \
  --name mihomo \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/debian-12.7.0-amd64-netinst.iso,media=cdrom \
  --scsi0 local-lvm:16 \
  --boot order=scsi0 \
  --ostype l26 \
  --onboot 1
```

#### 1.2 安装 Debian 系统

1. 启动虚拟机
2. 选择 "Install" (不要选 Graphical Install)
3. 安装配置：
   - 语言：English
   - 地区：其他 → 亚洲 → 中国
   - 键盘：American English
   - 主机名：mihomo
   - 域名：留空
   - Root 密码：设置强密码
   - 创建用户：可选
   - 分区：使用整个磁盘 → 所有文件放在一个分区
   - 软件选择：**只选 SSH server 和 standard system utilities**

4. 完成安装，重启

#### 1.3 配置静态 IP

登录虚拟机后：

```bash
# 编辑网络配置
nano /etc/network/interfaces
```

配置内容：
```bash
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ens18
iface ens18 inet static
    address 10.0.0.4
    netmask 255.255.255.0
    gateway 10.0.0.2
    dns-nameservers 223.5.5.5 119.29.29.29
```

重启网络：
```bash
systemctl restart networking

# 验证IP
ip addr show ens18
ping -c 4 10.0.0.2
```

#### 1.4 安装 mihomo

```bash
# 更新系统
apt update && apt upgrade -y

# 安装必要工具
apt install -y curl wget unzip sudo ca-certificates

# 下载并运行安装脚本（从本地下载的脚本）
# 或者手动安装：

# 检测架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64) MIHOMO_ARCH="linux-amd64" ;;
    aarch64) MIHOMO_ARCH="linux-arm64" ;;
    *) echo "不支持的架构"; exit 1 ;;
esac

# 获取最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"

# 下载并安装
wget -O /tmp/mihomo.gz "${DOWNLOAD_URL}"
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm /tmp/mihomo.gz

# 创建配置目录
mkdir -p /etc/mihomo
```

#### 1.5 配置 mihomo

创建配置文件：
```bash
nano /etc/mihomo/config.yaml
```

基础配置（记得添加您的代理节点）：
```yaml
# mihomo 配置文件
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: ""

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

proxies:
  # 在这里添加您的代理节点
  - name: "节点1"
    type: ss
    server: your-server.com
    port: 8388
    cipher: aes-256-gcm
    password: "your-password"

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - 节点1
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```

#### 1.6 创建 systemd 服务

```bash
nano /etc/systemd/system/mihomo.service
```

内容：
```ini
[Unit]
Description=mihomo Daemon
After=network.target

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
Restart=always
ExecStartPre=/usr/bin/sleep 1s
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
systemctl daemon-reload
systemctl enable mihomo
systemctl start mihomo
systemctl status mihomo
```

### 第二步：创建 AdGuard Home 虚拟机

#### 2.1 在 Proxmox 创建虚拟机

**通过 Web 界面**（类似 mihomo）：

```
VM ID：101
名称：adguardhome
CPU：2 核
内存：1024 MB
磁盘：16 GB
网络：vmbr0
```

**通过命令行**：

```bash
qm create 101 \
  --name adguardhome \
  --memory 1024 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/debian-12.7.0-amd64-netinst.iso,media=cdrom \
  --scsi0 local-lvm:16 \
  --boot order=scsi0 \
  --ostype l26 \
  --onboot 1
```

#### 2.2 安装 Debian 系统

与 mihomo 相同的安装步骤，主机名设为：`adguardhome`

#### 2.3 配置静态 IP

```bash
nano /etc/network/interfaces
```

配置：
```bash
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address 10.0.0.5
    netmask 255.255.255.0
    gateway 10.0.0.2
    dns-nameservers 223.5.5.5 119.29.29.29
```

重启网络：
```bash
systemctl restart networking
ip addr show ens18
ping -c 4 10.0.0.2
```

#### 2.4 安装 AdGuard Home

```bash
# 更新系统
apt update && apt upgrade -y
apt install -y curl wget ca-certificates

# 检测架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64) AGH_ARCH="linux_amd64" ;;
    aarch64) AGH_ARCH="linux_arm64" ;;
    *) echo "不支持的架构"; exit 1 ;;
esac

# 获取最新版本并下载
LATEST_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${LATEST_VERSION}/AdGuardHome_${AGH_ARCH}.tar.gz"

wget -O /tmp/adguardhome.tar.gz "${DOWNLOAD_URL}"
tar -xzf /tmp/adguardhome.tar.gz -C /opt/
rm /tmp/adguardhome.tar.gz

# 安装为服务
cd /opt/AdGuardHome
./AdGuardHome -s install
./AdGuardHome -s start
```

#### 2.5 初始化 AdGuard Home

1. 浏览器访问：`http://10.0.0.5:3000`
2. 按照向导完成初始配置：
   - 设置管理员账号和密码
   - Web 界面端口：3000（或保持默认）
   - DNS 端口：53

3. 配置上游 DNS：
   ```
   设置 → DNS 设置 → 上游 DNS 服务器
   添加：10.0.0.4:53
   ```

4. 配置广告过滤规则（参考之前的 adguardhome-rules.md）

### 第三步：配置 RouterOS

#### 3.1 基础配置

**通过 Terminal 或 WinBox**：

```bash
# 设置路由器自身 DNS
/ip dns set servers=10.0.0.5

# 设置 DHCP 分发的 DNS
/ip dhcp-server network set [find] dns-server=10.0.0.5

# 启用 DNS 缓存
/ip dns set allow-remote-requests=yes cache-size=4096KiB
```

#### 3.2 为虚拟机绑定静态 IP（可选但推荐）

```bash
# 查看当前 DHCP 租约
/ip dhcp-server lease print

# 找到 mihomo 和 adguardhome 的 MAC 地址，然后绑定
/ip dhcp-server lease add \
    address=10.0.0.4 \
    mac-address=XX:XX:XX:XX:XX:XX \
    server=defconf \
    comment="mihomo VM"

/ip dhcp-server lease add \
    address=10.0.0.5 \
    mac-address=XX:XX:XX:XX:XX:XX \
    server=defconf \
    comment="AdGuard Home VM"
```

#### 3.3 添加静态 DNS 记录

```bash
/ip dns static add \
    name=mihomo.home \
    address=10.0.0.4 \
    comment="mihomo Proxy"

/ip dns static add \
    name=adguard.home \
    address=10.0.0.5 \
    comment="AdGuard Home"
```

#### 3.4 配置强制 DNS 劫持（可选）

```bash
# 创建本地 DNS 白名单
/ip firewall address-list add \
    list=LOCAL_DNS \
    address=10.0.0.5 \
    comment="AdGuard Home"

/ip firewall address-list add \
    list=LOCAL_DNS \
    address=10.0.0.4 \
    comment="mihomo DNS"

# DNS 劫持规则
/ip firewall nat add \
    chain=dstnat \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=dst-nat \
    to-addresses=10.0.0.5 \
    to-ports=53 \
    comment="Force DNS to AdGuard Home"

# 防止 DNS 泄漏
/ip firewall filter add \
    chain=forward \
    protocol=udp \
    dst-port=53 \
    dst-address-list=!LOCAL_DNS \
    action=reject \
    reject-with=icmp-network-unreachable \
    comment="Block Direct DNS Queries"
```

## ✅ 验证配置

### 1. 测试网络连通性

在 RouterOS：
```bash
/ping 10.0.0.4 count=10
/ping 10.0.0.5 count=10
```

### 2. 测试 DNS 解析

在 RouterOS：
```bash
/tool fetch url=http://www.google.com mode=http
```

在客户端设备：
```bash
nslookup google.com
nslookup baidu.com
```

### 3. 测试广告拦截

浏览器访问：https://ads-blocker.com/zh-CN/testing/

应该看到大部分广告被拦截。

### 4. 查看 AdGuard Home 统计

访问：`http://10.0.0.5:3000`

查看：
- 查询总数
- 已拦截查询
- 拦截率

### 5. 查看 mihomo 状态

在 mihomo VM：
```bash
systemctl status mihomo
journalctl -u mihomo -f
```

或访问控制面板：
- Yacd: http://yacd.metacubex.one
- API 地址：`http://10.0.0.4:9090`

### 6. 测试代理功能

在客户端设备浏览器配置代理：
```
HTTP 代理: 10.0.0.4:7890
SOCKS5 代理: 10.0.0.4:7890
```

访问 Google、YouTube 等网站测试。

## 🎨 高级配置

### 1. mihomo 配置优化

编辑 `/etc/mihomo/config.yaml`，参考项目的 `docs/config-examples.yaml` 添加更多功能：

- 多个代理节点
- 自动选择/负载均衡
- 更详细的分流规则
- TUN 模式（如果需要透明代理）

### 2. AdGuard Home 规则优化

参考 `docs/adguardhome-rules.md` 添加更多过滤规则：

- anti-AD（国内广告）
- AdGuard DNS Filter（国际广告）
- EasyList（基础规则）
- 隐私保护规则
- 反追踪规则

### 3. 性能优化

#### mihomo VM：

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf
```

#### AdGuard Home：

在 Web 界面：
```
设置 → DNS 设置 → DNS 缓存配置
缓存大小：10000000 (10MB)
```

### 4. 自动更新脚本

#### mihomo 自动更新

创建 `/root/update-mihomo.sh`：
```bash
#!/bin/bash
ARCH=$(uname -m)
case ${ARCH} in
    x86_64) MIHOMO_ARCH="linux-amd64" ;;
    aarch64) MIHOMO_ARCH="linux-arm64" ;;
    *) exit 1 ;;
esac

LATEST_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_VERSION}/mihomo-${MIHOMO_ARCH}-${LATEST_VERSION}.gz"

systemctl stop mihomo
wget -O /tmp/mihomo.gz "${DOWNLOAD_URL}"
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm /tmp/mihomo.gz
systemctl start mihomo
echo "mihomo 已更新到 ${LATEST_VERSION}"
```

添加执行权限：
```bash
chmod +x /root/update-mihomo.sh
```

## 📊 监控和维护

### 查看服务状态

**mihomo VM**：
```bash
systemctl status mihomo
journalctl -u mihomo -f
netstat -tuln | grep -E '7890|9090|53'
```

**AdGuard Home VM**：
```bash
/opt/AdGuardHome/AdGuardHome -s status
journalctl -f | grep AdGuardHome
```

### 查看资源使用

```bash
# CPU 和内存
top
htop

# 磁盘使用
df -h

# 网络连接
ss -tuln
```

### 日志位置

- mihomo: `journalctl -u mihomo`
- AdGuard Home: `/opt/AdGuardHome/data/querylog.json`
- 系统日志: `/var/log/syslog`

## 🚨 故障排查

### 问题 1：无法访问虚拟机

**检查**：
1. 虚拟机是否运行：在 Proxmox 查看状态
2. 网络配置是否正确：`ip addr show`
3. 防火墙是否阻止：`iptables -L -n`
4. 网关是否可达：`ping 10.0.0.2`

### 问题 2：DNS 不解析

**检查**：
1. AdGuard Home 是否运行：`/opt/AdGuardHome/AdGuardHome -s status`
2. mihomo DNS 是否正常：`dig @10.0.0.4 google.com`
3. 端口是否监听：`netstat -tuln | grep :53`

### 问题 3：广告拦截不生效

**检查**：
1. 规则是否已添加：AdGuard Home 管理界面查看
2. 规则是否已更新：点击"更新"按钮
3. DNS 是否指向正确：客户端查看 DNS 配置

### 问题 4：代理不工作

**检查**：
1. mihomo 服务状态：`systemctl status mihomo`
2. 配置文件语法：`/usr/local/bin/mihomo -d /etc/mihomo -t`
3. 代理节点是否可用：在 Yacd 面板测试延迟

## 📋 快速参考

### 常用命令

```bash
# mihomo 服务管理
systemctl start mihomo
systemctl stop mihomo
systemctl restart mihomo
systemctl status mihomo

# AdGuard Home 服务管理
/opt/AdGuardHome/AdGuardHome -s start
/opt/AdGuardHome/AdGuardHome -s stop
/opt/AdGuardHome/AdGuardHome -s restart
/opt/AdGuardHome/AdGuardHome -s status

# 查看日志
journalctl -u mihomo -f
journalctl -f | grep AdGuardHome

# 网络测试
ping 10.0.0.2
dig @10.0.0.5 google.com
curl -v http://www.google.com
```

### 访问地址

- mihomo 控制面板：http://yacd.metacubex.one （API: http://10.0.0.4:9090）
- AdGuard Home：http://10.0.0.5:3000
- Proxmox VE：https://pve-ip:8006

## 🔄 备份和恢复

### 备份 mihomo 配置

```bash
# 在 mihomo VM
tar czf /tmp/mihomo-backup.tar.gz /etc/mihomo
# 下载到本地保存
```

### 备份 AdGuard Home 配置

```bash
# 在 AdGuard Home VM
tar czf /tmp/adguard-backup.tar.gz /opt/AdGuardHome/data
# 下载到本地保存
```

### Proxmox 虚拟机备份

```bash
# 在 Proxmox 主机
vzdump 100 --storage local --compress zstd
vzdump 101 --storage local --compress zstd
```

## 💡 最佳实践

1. ✅ **定期备份**：每周备份一次配置
2. ✅ **监控日志**：定期查看系统和服务日志
3. ✅ **更新系统**：每月更新一次系统和软件
4. ✅ **测试配置**：修改配置后立即测试
5. ✅ **文档记录**：记录所有配置修改
6. ✅ **性能监控**：关注 CPU、内存、网络使用情况

## 📚 相关文档

- [ROUTEROS-CONFIG.md](ROUTEROS-CONFIG.md) - RouterOS 详细配置
- [INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md) - 组合方案指南  
- [adguardhome-rules.md](adguardhome-rules.md) - 广告过滤规则
- [config-examples.yaml](config-examples.yaml) - mihomo 配置示例

---

**🎉 配置完成后，您将拥有：**
- ✅ 基于 Debian 虚拟机的稳定服务
- ✅ 智能分流和广告过滤
- ✅ 全局 DNS 无污染
- ✅ RouterOS 主路由完美集成
- ✅ 易于维护和备份

**享受干净、快速、安全的网络体验！** 🚀

