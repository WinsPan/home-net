# BoomDNS 完整部署指南

**傻瓜式操作 - 跟着做就能成功**

---

## 🎯 最终效果

- ✅ 智能分流 - 国内外自动分流
- ✅ 广告过滤 - 全网广告拦截
- ✅ 容错保护 - 服务挂掉不断网
- ✅ 一键部署 - 复制粘贴完成

---

## 📋 准备工作

### 需要的设备
- ✅ Proxmox VE 服务器（已安装）
- ✅ RouterOS 路由器（MikroTik）
- ✅ 机场订阅地址（1个即可）

### IP 地址规划
| 设备 | IP 地址 | 用途 |
|------|---------|------|
| RouterOS | 10.0.0.2 | 网关路由器 |
| mihomo VM | 10.0.0.4 | 智能代理 |
| AdGuard VM | 10.0.0.5 | DNS 过滤 |
| 设备 DHCP | 10.0.0.100-200 | 自动分配 |

---

## 第一步：创建 mihomo 虚拟机

### 1.1 在 Proxmox 创建 VM

登录 Proxmox Web 界面：

1. 点击右上角 **"创建虚拟机"**
2. 填写配置：

```
【常规】
  节点: 选择你的节点
  VM ID: 100
  名称: mihomo

【操作系统】
  ISO 映像: debian-12-generic-amd64.iso
  类型: Linux
  版本: 6.x - 2.6 Kernel

【系统】
  保持默认

【硬盘】
  磁盘大小: 20 GB
  其他保持默认

【CPU】
  核心: 2

【内存】
  内存: 2048 MB (2GB)

【网络】
  桥接: vmbr0
  模型: VirtIO (半虚拟化)
```

3. 点击 **"完成"**
4. **不要启动**，先进行下一步配置

### 1.2 安装 Debian 12

1. 选择 VM 100，点击 **"启动"**
2. 点击 **"控制台"** 进入安装界面

**安装步骤：**

```
1. 选择 "Install"（文本安装）
2. 语言: English
3. 位置: Other → Asia → China
4. 键盘: American English
5. 主机名: mihomo
6. 域名: 留空
7. Root 密码: 设置一个密码（记住！）
8. 创建用户: 跳过（直接用 root）
9. 分区: 
   - Guided - use entire disk
   - All files in one partition
   - Finish partitioning
   - Yes (确认写入)
10. 软件源:
    - 镜像: China → mirrors.ustc.edu.cn
    - 不使用网络镜像
11. 软件选择:
    - 只选择 "SSH server"
    - 其他全部取消
12. 安装 GRUB: Yes
13. 完成，重启
```

### 1.3 配置静态 IP

重启后，在控制台登录：

```bash
# 用户名: root
# 密码: 你设置的密码
```

**配置网络：**

```bash
# 1. 编辑网络配置
nano /etc/network/interfaces
```

**删除所有内容，粘贴以下内容：**

```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address 10.0.0.4/24
    gateway 10.0.0.2
    dns-nameservers 8.8.8.8
```

按 `Ctrl+X`，按 `Y`，按 `Enter` 保存

```bash
# 2. 重启网络
systemctl restart networking

# 3. 测试网络
ping -c 3 8.8.8.8
# 应该看到 3 packets transmitted, 3 received

# 4. 记录 IP 地址
ip addr show ens18
# 应该显示 inet 10.0.0.4/24
```

### 1.4 安装 mihomo

**在 SSH 客户端连接（推荐）：**

Windows 用户：打开 PowerShell  
Mac/Linux 用户：打开终端

```bash
ssh root@10.0.0.4
# 输入密码
```

**执行安装脚本：**

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh | bash
```

**按照提示操作：**

```
1. 选择配置类型:
   输入: 1  (智能配置)
   
2. 输入机场订阅地址:
   粘贴你的订阅地址
   例如: https://your-airport.com/api/v1/client/subscribe?token=xxx
   
3. 等待安装完成
   
4. 记录显示的 API 密钥（用于 Web 管理）
```

**验证安装：**

```bash
# 1. 检查服务状态
systemctl status mihomo
# 应该显示 "active (running)"

# 2. 测试代理
curl -x http://127.0.0.1:7890 https://www.google.com -I
# 应该返回 "HTTP/1.1 200 OK" 或类似响应

# 3. 查看日志
journalctl -u mihomo -n 20
# 应该没有 ERROR 信息
```

✅ **第一步完成！mihomo 已安装**

---

## 第二步：创建 AdGuard Home 虚拟机

### 2.1 在 Proxmox 创建 VM

重复第一步的操作，但配置不同：

```
VM ID: 101
名称: adguardhome
CPU: 1 核
内存: 1024 MB (1GB)
硬盘: 10 GB
其他配置相同
```

### 2.2 安装 Debian 12

**完全相同的安装步骤**，只有主机名不同：

```
主机名: adguardhome
```

### 2.3 配置静态 IP

登录后配置网络：

```bash
nano /etc/network/interfaces
```

**粘贴以下内容：**

```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address 10.0.0.5/24
    gateway 10.0.0.2
    dns-nameservers 8.8.8.8
```

```bash
# 重启网络
systemctl restart networking

# 测试
ping -c 3 8.8.8.8
```

### 2.4 安装 AdGuard Home

```bash
# SSH 连接
ssh root@10.0.0.5

# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh | bash
```

**等待安装完成**

### 2.5 初始化 AdGuard Home

**在浏览器打开：**

```
http://10.0.0.5:3000
```

**初始化步骤：**

```
1. 点击 "开始配置"

2. Web 管理界面:
   - 端口保持 3000（或改为 80）
   
3. DNS 服务器设置:
   - 端口: 53
   
4. 创建管理员账号:
   - 用户名: admin
   - 密码: 设置一个强密码（记住！）
   
5. 点击 "下一步" → "完成"
```

### 2.6 配置 DNS 设置

登录后（`http://10.0.0.5`）：

**点击左侧 "设置" → "DNS 设置"：**

```
【上游 DNS 服务器】
删除默认的，添加以下内容:

127.0.0.1:1053
https://doh.pub/dns-query
https://dns.alidns.com/dns-query
223.5.5.5
119.29.29.29


【Bootstrap DNS 服务器】
223.5.5.5
119.29.29.29


【勾选】
☑ 启用并行请求
☑ 启用 DNSSEC


【速率限制】
30
```

点击页面底部 **"保存"**

### 2.7 添加过滤规则

**点击 "过滤器" → "DNS 封锁清单"：**

点击 **"添加阻止列表"** → **"添加自定义列表"**

**逐个添加以下规则：**

```
名称: Anti-AD
URL: https://anti-ad.net/easylist.txt
点击 "保存"

名称: AdGuard Filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
点击 "保存"

名称: EasyList China
URL: https://easylist-downloads.adblockplus.org/easylistchina.txt
点击 "保存"
```

**添加完成后，点击 "立即更新过滤器"**

等待更新完成（显示规则数量）

✅ **第二步完成！AdGuard Home 已配置**

---

## 第三步：配置 RouterOS

### 3.1 连接 RouterOS

**Winbox（推荐）：**
- 下载 Winbox: https://mikrotik.com/download
- 连接到你的 RouterOS IP

**或者使用 SSH：**
```bash
ssh admin@你的RouterOS-IP
```

### 3.2 基础 DNS 配置

**复制粘贴以下命令（一次一行）：**

```bash
# 1. 配置 DNS（重要：多 DNS 容错）
/ip dns set servers=10.0.0.5,223.5.5.5,119.29.29.29 allow-remote-requests=yes cache-size=10240

# 2. 创建 DHCP IP 池
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

# 3. 创建 DHCP 服务器
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool

# 4. 配置 DHCP 网络
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.5,223.5.5.5,119.29.29.29
```

**验证配置：**

```bash
# 查看 DNS 配置
/ip dns print
# 应该显示 servers: 10.0.0.5,223.5.5.5,119.29.29.29

# 查看 DHCP 服务器
/ip dhcp-server print
# 应该显示 dhcp1 且 invalid=no
```

### 3.3 DNS 劫持（可选但推荐）

```bash
# 强制所有 DNS 查询到 AdGuard Home
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 dst-address=!10.0.0.5 action=dst-nat to-addresses=10.0.0.5 comment="DNS Hijack"
```

### 3.4 防火墙规则

```bash
# 1. INPUT 链（保护路由器）
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept established"
/ip firewall filter add chain=input src-address=10.0.0.0/24 action=accept comment="Accept from LAN"
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"
/ip firewall filter add chain=input action=drop comment="Drop all other"

# 2. FORWARD 链（加速转发）
/ip firewall filter add chain=forward connection-state=established,related action=fasttrack-connection comment="FastTrack"
/ip firewall filter add chain=forward connection-state=established,related action=accept comment="Accept established"

# 3. NAT（网络地址转换）
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="Masquerade"
```

**注意：** `ether1` 是 WAN 口，根据你的实际情况修改

### 3.5 健康检查脚本（容错关键）

```bash
# 创建检查脚本
/system script add name=check-adguard source={
    :if ([/ping 10.0.0.5 count=2] = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
        /log warning "AdGuard DOWN! DNS hijack disabled."
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}

# 创建定时任务（每分钟检查）
/system scheduler add name=check-schedule on-event=check-adguard interval=1m comment="Health check"
```

✅ **第三步完成！RouterOS 已配置**

---

## 第四步：配置代理（二选一）

### 方案 A：手动设置代理（推荐新手）✅

**无需额外配置**，在设备上设置代理即可：

#### Windows 设置

```
1. 设置 → 网络和 Internet → 代理
2. 手动设置代理
3. 地址: 10.0.0.4
4. 端口: 7890
5. 保存
```

#### macOS 设置

```
1. 系统偏好设置 → 网络
2. 选择你的网络 → 高级 → 代理
3. 勾选 "网页代理(HTTP)" 和 "安全网页代理(HTTPS)"
4. 服务器: 10.0.0.4
5. 端口: 7890
6. 好
```

#### iOS/Android 设置

```
1. WiFi 设置 → 选择当前 WiFi
2. 配置代理 → 手动
3. 服务器: 10.0.0.4
4. 端口: 7890
5. 存储/保存
```

#### 浏览器扩展（最推荐）

**Chrome/Edge：**
1. 安装 "Proxy SwitchyOmega"
2. 新建情景模式 → 代理服务器
3. 协议: HTTP
4. 服务器: 10.0.0.4
5. 端口: 7890

**一键切换代理和直连！**

---

### 方案 B：透明代理（高级用户）🔧

**需要额外配置，所有设备自动生效**

详细步骤请查看：[docs/CONFIG.md#6-代理配置](docs/CONFIG.md#6-代理配置)

---

## 第五步：测试验证

### 5.0 自动验证（推荐）⭐

**下载验证脚本并运行：**

```bash
# 下载验证脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/verify-deployment.sh -o verify.sh

# 运行验证
bash verify.sh
```

脚本会自动测试：
- ✅ 网络连接
- ✅ mihomo 服务和代理
- ✅ AdGuard Home 服务和 DNS
- ✅ RouterOS 连接
- ✅ DNS 劫持
- ✅ 广告拦截
- ✅ 智能分流

**如果所有测试通过，部署成功！**

---

### 5.1 手动测试 DNS（可选）

如果自动验证失败，可以手动测试：

**在任意客户端：**

```bash
# Windows PowerShell / Mac Terminal

# 测试 DNS 解析
nslookup google.com
# 应该返回 IP 地址

nslookup baidu.com
# 应该返回 IP 地址
```

### 5.2 测试广告过滤

**在浏览器访问：**

```
http://testadblock.com
```

应该显示：**广告被拦截！**

### 5.3 测试代理

**使用代理访问 Google：**

```bash
# 测试代理（手动设置代理后）
curl https://www.google.com -I
# 应该返回 200 OK

# 查看当前 IP
curl https://ip.sb
# 应该显示代理节点的 IP（非本地 IP）
```

### 5.4 测试智能分流

**访问国内网站（应该直连）：**

```bash
curl https://www.baidu.com -I
# 速度很快

# 查看 mihomo 日志
ssh root@10.0.0.4
journalctl -u mihomo -n 20 | grep baidu
# 应该显示 "match DIRECT" 或类似
```

**访问国外网站（应该走代理）：**

```bash
curl https://www.google.com -I
# 能正常访问

# 查看 mihomo 日志
journalctl -u mihomo -n 20 | grep google
# 应该显示节点名称
```

✅ **所有测试通过！部署成功！**

---

## 第六步：Web 管理界面

### 6.1 mihomo 管理界面

**访问：**
```
http://10.0.0.4:9090
```

**如果设置了 API 密钥，输入密钥登录**

**功能：**
- 查看所有节点和延迟
- 手动切换节点
- 查看连接统计
- 实时日志

### 6.2 AdGuard Home 管理界面

**访问：**
```
http://10.0.0.5
```

**功能：**
- 查看拦截统计
- 查看 DNS 查询日志
- 管理过滤规则
- 更新规则

---

## 常见问题快速解决

### 🔧 自动诊断工具（推荐）⭐

遇到问题？先运行诊断工具：

```bash
# 下载诊断脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/diagnose.sh -o diagnose.sh

# 运行诊断
bash diagnose.sh
```

诊断工具会：
- 🔍 检查所有服务状态
- 🔍 测试网络连接
- 🔍 诊断常见问题
- 💡 给出解决方案

---

### ❌ 问题：无法上网

**解决步骤：**

```bash
# 1. 检查 RouterOS DNS
# 登录 RouterOS
/ip dns print
# 应该显示 10.0.0.5,223.5.5.5,119.29.29.29

# 2. 测试 DNS
ping 10.0.0.5
# 应该能 ping 通

# 3. 临时禁用 DNS 劫持
/ip firewall nat disable [find comment="DNS Hijack"]

# 4. 测试是否恢复
# 在客户端测试上网
```

---

### ❌ 问题：广告没有被拦截

**解决步骤：**

```bash
# 1. 检查 AdGuard Home 规则
# 浏览器打开 http://10.0.0.5
# 过滤器 → 检查规则是否启用

# 2. 更新规则
# 点击 "立即更新过滤器"

# 3. 清除 DNS 缓存
# Windows:
ipconfig /flushdns

# Mac:
sudo dscacheutil -flushcache

# 4. 重启浏览器
```

---

### ❌ 问题：代理不工作

**解决步骤：**

```bash
# 1. 检查 mihomo 状态
ssh root@10.0.0.4
systemctl status mihomo
# 应该显示 active (running)

# 2. 测试代理
curl -x http://127.0.0.1:7890 https://www.google.com -I
# 应该返回 200 OK

# 3. 查看日志
journalctl -u mihomo -n 50
# 查找 ERROR 信息

# 4. 检查订阅更新
ls -lh /etc/mihomo/providers/
# 应该有 main.yaml 文件

# 5. 手动更新订阅
curl -X PUT http://10.0.0.4:9090/providers/proxies/main-airport
```

---

### ❌ 问题：订阅无法更新

**解决步骤：**

```bash
# 1. 测试订阅地址
curl -I "你的订阅地址"
# 应该返回 200 OK

# 2. 检查网络
ssh root@10.0.0.4
ping -c 3 8.8.8.8
# 应该能 ping 通

# 3. 查看详细日志
journalctl -u mihomo -n 100 | grep -i "provider\|error"

# 4. 手动下载测试
wget -O /tmp/test.yaml "你的订阅地址"
cat /tmp/test.yaml
# 应该看到节点信息

# 5. 如果订阅不兼容，使用订阅转换
# 编辑配置
nano /etc/mihomo/config.yaml
# 修改 url 为:
# url: "https://sub.xeton.dev/sub?target=clash&url=你的订阅地址"
```

---

## 维护操作

### 更新 mihomo

```bash
ssh root@10.0.0.4
/opt/mihomo/update-mihomo.sh
```

### 更新 AdGuard Home

```
浏览器打开: http://10.0.0.5
设置 → 常规设置 → 检查更新
```

### 备份配置

```bash
# mihomo
ssh root@10.0.0.4
tar -czf ~/mihomo-backup-$(date +%Y%m%d).tar.gz /etc/mihomo

# AdGuard Home
ssh root@10.0.0.5
tar -czf ~/adguard-backup-$(date +%Y%m%d).tar.gz /opt/AdGuardHome

# RouterOS
/export file=router-backup-$(date +%Y%m%d)
```

---

## 🎉 完成！

你现在拥有：

✅ **智能分流** - 国内外自动识别  
✅ **广告过滤** - 全网广告拦截  
✅ **容错保护** - 服务挂掉不断网  
✅ **Web 管理** - 可视化控制  
✅ **自动更新** - 订阅和规则自动维护  

---

## 下一步

- 🔧 [高级配置](docs/CONFIG.md) - 多机场、节点筛选、透明代理
- 📖 [RouterOS 详细配置](docs/ROUTEROS.md) - 高级路由功能
- ❓ [常见问题](docs/CONFIG.md#常见问题) - 完整 FAQ

---

**遇到问题？**
- 查看 [GitHub Issues](https://github.com/WinsPan/home-net/issues)
- 提交问题时附上日志

**觉得有用？**
- ⭐ Star 这个项目
- 分享给朋友

