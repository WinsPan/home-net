# 快速开始 - 10 分钟部署

**最简单的部署方式**

---

## 准备工作（5 分钟）

### 1. 在 Proxmox 创建两个 VM

**VM 1: mihomo**
```
VM ID: 100
IP: 10.0.0.4/24
CPU: 2 核
内存: 2GB
硬盘: 20GB
系统: Debian 12
```

**VM 2: AdGuard Home**
```
VM ID: 101
IP: 10.0.0.5/24
CPU: 1 核
内存: 1GB
硬盘: 10GB
系统: Debian 12
```

### 2. 配置静态 IP

**两个 VM 都执行：**

```bash
# 编辑网络配置
nano /etc/network/interfaces
```

**mihomo (10.0.0.4)：**
```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address 10.0.0.4/24
    gateway 10.0.0.2
    dns-nameservers 8.8.8.8
```

**AdGuard Home (10.0.0.5)：**
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

---

## 一键部署（5 分钟）

在**你的电脑**（Mac/Linux/Windows WSL）上运行：

```bash
# 下载部署脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh

# 运行部署
bash deploy.sh
```

### 脚本会询问：

1. **mihomo IP**: `10.0.0.4` (按 Enter)
2. **mihomo root 密码**: 输入密码
3. **机场订阅地址**: 粘贴你的订阅 URL
4. **AdGuard Home IP**: `10.0.0.5` (按 Enter)
5. **AdGuard Home root 密码**: 输入密码
6. **RouterOS IP**: `10.0.0.2` (按 Enter)
7. **确认信息**: 输入 `y`

### 脚本会自动：

✅ 安装 mihomo  
✅ 安装 AdGuard Home  
✅ 生成 RouterOS 配置  
✅ 验证部署  

---

## 完成配置（3 步）

### 1. 初始化 AdGuard Home

浏览器打开：`http://10.0.0.5:3000`

```
1. 点击「开始配置」
2. 端口保持默认
3. 创建管理员账号
4. 完成
```

登录后配置 DNS：

```
设置 → DNS 设置

【上游 DNS 服务器】
删除默认的，添加以下内容：

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

点击「保存」
```

添加过滤规则：

```
过滤器 → DNS 封锁清单 → 添加自定义列表

规则 1:
名称: Anti-AD
URL: https://anti-ad.net/easylist.txt

规则 2:
名称: AdGuard Filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

规则 3:
名称: EasyList China
URL: https://easylist-downloads.adblockplus.org/easylistchina.txt

点击「立即更新过滤器」
```

### 2. 配置 RouterOS

打开生成的文件：`routeros-config.rsc`

复制所有内容，登录 RouterOS，逐行粘贴执行

**注意：** 将 `ether1` 改为你的实际 WAN 口名称

### 3. 设置设备代理

**Windows:**
```
设置 → 网络和 Internet → 代理
地址: 10.0.0.4
端口: 7890
```

**macOS:**
```
系统偏好设置 → 网络 → 高级 → 代理
网页代理(HTTP): 10.0.0.4:7890
安全网页代理(HTTPS): 10.0.0.4:7890
```

**浏览器（最推荐）:**
```
安装扩展: SwitchyOmega
代理服务器: 10.0.0.4:7890
```

---

## 测试验证

### 1. 测试代理
```bash
curl -x http://10.0.0.4:7890 https://www.google.com -I
# 应该返回 200 OK
```

### 2. 测试广告拦截
```
浏览器访问: http://testadblock.com
应该显示: 广告被拦截
```

### 3. 查看管理界面
```
mihomo:       http://10.0.0.4:9090
AdGuard Home: http://10.0.0.5
```

---

## 完成！🎉

**你现在拥有：**
- ✅ 智能分流 - 国内外自动识别
- ✅ 广告过滤 - DNS 级别全网拦截
- ✅ 容错保护 - 服务故障不断网

---

## 常见问题

### 无法连接 SSH

**检查：**
```bash
# 测试网络
ping 10.0.0.4
ping 10.0.0.5

# 测试 SSH
ssh root@10.0.0.4
```

### 部署失败

**运行诊断：**
```bash
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/diagnose.sh | bash
```

### 需要更多帮助

**查看文档：**
- [完整部署指南](GUIDE.md) - 详细步骤
- [配置文档](docs/CONFIG.md) - 高级配置
- [常用命令](CHEATSHEET.md) - 命令速查

---

**项目地址:** https://github.com/WinsPan/home-net

