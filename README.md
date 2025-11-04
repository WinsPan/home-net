# BoomDNS - 家庭网络解决方案

> sing-box (通用代理) + AdGuard Home (广告过滤) + Clash 转换服务 + RouterOS

全自动化部署，简单、高效、专业。

---

## ✨ 特性

- 🚀 **分离式部署** - PVE 创建 VM，服务独立安装
- 🎯 **一键安装** - 每个服务单独的安装脚本
- ☁️ **Cloud-init** - VM 自动配置网络
- 🔑 **密码登录** - SSH 密码认证，无需密钥
- 🔧 **sing-box** - 通用代理平台，支持多种协议
- 🔄 **自动转换** - Clash 订阅自动转换为 sing-box 格式
- 🛡️ **广告过滤** - AdGuard Home DNS 级别拦截
- 🌐 **RouterOS 集成** - 透明代理 + DNS 配置

---

## 📋 IP 地址规划

```
RouterOS:        10.0.0.2  (主路由)
sing-box:        10.0.0.3  (代理服务)
AdGuard Home:    10.0.0.4  (DNS 服务)
```

**注意：** Clash 转换服务可以安装在 sing-box VM 上（默认），也可以单独部署。

---

## 🚀 快速开始

### 方式 1：引导式部署（推荐新手）⭐

```bash
# 在 Proxmox 节点运行
git clone https://github.com/WinsPan/home-net.git
cd home-net
bash setup.sh
```

**会自动显示：**
- 📚 详细部署指南
- ⚡ 快速命令
- 🎯 分步操作说明

---

### 方式 2：手动部署（推荐进阶）⭐⭐

#### 第一步：创建 VM（在 PVE 节点）

```bash
# 创建 sing-box VM
bash vm/create-vm.sh

# 配置：
VM 名称: sing-box
VMID: 101
CPU: 2 核
内存: 2048 MB
磁盘: 10 GB
IP: 10.0.0.3/24
网关: 10.0.0.2
root密码: ******
```

```bash
# 创建 AdGuard Home VM
bash vm/create-vm.sh

# 配置：
VM 名称: adguardhome
VMID: 102
CPU: 2 核
内存: 2048 MB
磁盘: 10 GB
IP: 10.0.0.4/24
网关: 10.0.0.2
root密码: ******
```

#### 第二步：安装 Clash 转换服务（在 sing-box VM 或独立 VM）

**推荐安装在 sing-box VM 上：**
```bash
# SSH 登录 sing-box VM
ssh root@10.0.0.3

# 先安装转换服务
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/converter/install.sh | bash
```

#### 第三步：安装 sing-box（在 sing-box VM）

**方式 A：在线安装（推荐）**
```bash
# 在 sing-box VM 上运行
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/sing-box/install.sh | bash

# 输入订阅地址
订阅地址（Clash 或 sing-box 格式）: https://your-subscription-url
订阅是 Clash 格式吗？需要转换吗？(y/n) [n]: y
```

**方式 B：本地脚本**
```bash
# 在 PVE 节点传输脚本
scp services/sing-box/install.sh root@10.0.0.3:/tmp/

# SSH 执行
ssh root@10.0.0.3 'bash /tmp/install.sh'
```

#### 第四步：安装 AdGuard Home（在 AdGuard Home VM）

**方式 A：在线安装（推荐）**
```bash
# SSH 登录 AdGuard Home VM
ssh root@10.0.0.4

# 运行安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash

# 访问 Web 界面初始化
http://10.0.0.4:3000
```

**方式 B：本地脚本**
```bash
# 在 PVE 节点传输脚本
scp services/adguardhome/install.sh root@10.0.0.4:/tmp/

# SSH 执行
ssh root@10.0.0.4 'bash /tmp/install.sh'
```

---

## 🎯 服务访问

### sing-box 代理服务
```
Mixed 代理: http://10.0.0.3:7890 (HTTP + SOCKS5)
```

### Clash 转换服务
```
转换 API: http://10.0.0.3:8080/convert?url=<订阅地址>
```

### AdGuard Home 管理面板
```
Web 界面: http://10.0.0.4:3000
DNS 端口: 10.0.0.4:53
```

---

## 🔧 服务管理

### sing-box

```bash
# SSH 登录 sing-box VM
ssh root@10.0.0.3

# 管理命令
systemctl status sing-box       # 查看状态
systemctl restart sing-box      # 重启服务
systemctl stop sing-box         # 停止服务
journalctl -u sing-box -f       # 查看日志

# 配置文件
/etc/sing-box/config.json
```

### Clash 转换服务

```bash
# SSH 登录 sing-box VM
ssh root@10.0.0.3

# 管理命令
systemctl status clash-converter      # 查看状态
systemctl restart clash-converter     # 重启服务
journalctl -u clash-converter -f      # 查看日志

# 测试转换
curl 'http://127.0.0.1:8080/convert?url=<订阅地址>' | jq
```

### AdGuard Home

```bash
# SSH 登录 AdGuard Home VM
ssh root@10.0.0.4

# 管理命令
systemctl status AdGuardHome      # 查看状态
systemctl restart AdGuardHome     # 重启服务
systemctl stop AdGuardHome        # 停止服务
journalctl -u AdGuardHome -f      # 查看日志
```

---

## 📚 配置指南

### AdGuard Home 初始化

1. 访问：`http://10.0.0.4:3000`
2. 设置管理员账号密码
3. DNS 监听端口：`53`（默认）
4. Web 管理端口：`3000`（默认）

**推荐上游 DNS：**
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
223.5.5.5
```

**推荐过滤规则：**
```
https://anti-ad.net/easylist.txt
AdGuard DNS filter (内置)
EasyList China (内置)
```

### RouterOS 配置

```bash
# 生成配置
bash routeros/generate-config.sh

# 复制生成的配置到 RouterOS 执行
```

**主要功能：**
- DHCP DNS 指向 AdGuard Home (10.0.0.4)
- 健康检查和故障转移
- 防火墙规则

---

## 🔄 Clash 订阅转换说明

### 转换服务工作流程

```
1. Clash 订阅 URL
   ↓
2. 转换服务 (http://10.0.0.3:8080/convert?url=...)
   ↓
3. sing-box 配置 (JSON 格式)
   ↓
4. sing-box 加载配置
```

### 转换示例

```bash
# 手动转换测试
curl 'http://10.0.0.3:8080/convert?url=https://your-clash-subscription' > config.json

# 查看转换结果
cat config.json | jq
```

### 支持的协议

转换服务支持以下 Clash 协议：
- ✅ Shadowsocks (ss)
- ✅ VMess
- ✅ Trojan
- ⚠️ 其他协议可能需要手动配置

---

## 🧪 测试验证

### 测试 sing-box 代理

```bash
# 在任意机器测试
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 应该返回 HTTP 200
```

### 测试 AdGuard Home DNS

```bash
# 测试 DNS 解析
nslookup google.com 10.0.0.4

# 测试广告拦截
nslookup ad.doubleclick.net 10.0.0.4
# 应该返回 0.0.0.0
```

### 测试转换服务

```bash
# 测试转换 API
curl 'http://10.0.0.3:8080/convert?url=<你的clash订阅>' | jq '.outbounds | length'

# 应该返回节点数量
```

---

## 📦 项目结构

```
boomdns/
├── setup.sh                          # 引导脚本（PVE 节点）
├── vm/
│   └── create-vm.sh                  # VM 创建（PVE 节点）
├── services/
│   ├── sing-box/
│   │   └── install.sh                # sing-box 安装（sing-box VM）
│   ├── converter/
│   │   └── install.sh                # Clash 转换服务（sing-box VM 或独立）
│   └── adguardhome/
│       └── install.sh                # AdGuard Home 安装（AdGuard Home VM）
├── routeros/
│   └── generate-config.sh            # RouterOS 配置生成（PVE 节点）
└── docs/
    └── CONFIG.md                     # 详细配置说明
```

---

## 💡 使用场景

### 场景 1：客户端代理上网

**配置代理：**
```
HTTP/SOCKS5: 10.0.0.3:7890
```

**自动拦截广告：**
- 所有客户端 DNS 请求自动经过 AdGuard Home
- 广告域名被拦截返回 0.0.0.0

### 场景 2：RouterOS 透明代理

**执行 RouterOS 配置后：**
- 所有设备自动使用 AdGuard Home DNS
- 特定流量自动经过 sing-box 代理
- 无需配置客户端

### 场景 3：Clash 订阅迁移

**如果你有 Clash 订阅：**
1. 先安装转换服务
2. 安装 sing-box 时选择转换
3. 自动将 Clash 订阅转换为 sing-box 格式

---

## 🔄 更新服务

### 更新 sing-box

```bash
ssh root@10.0.0.3

# 重新运行安装脚本即可
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/sing-box/install.sh | bash
```

### 更新 AdGuard Home

```bash
ssh root@10.0.0.4

# 重新运行安装脚本即可
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/adguardhome/install.sh | bash
```

### 更新转换服务

```bash
ssh root@10.0.0.3

# 重新运行安装脚本即可
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/services/converter/install.sh | bash
```

---

## ❓ 常见问题

### Q: 端口 53 被占用？
A: AdGuard Home 安装脚本会自动停止 systemd-resolved 并释放端口。

### Q: SSH 无法连接？
A: 确保 VM 已启动，IP 地址配置正确，可以 ping 通。

### Q: Clash 订阅转换失败？
A: 确保转换服务正常运行：`systemctl status clash-converter`

### Q: sing-box 不支持我的协议？
A: 可以手动编辑 `/etc/sing-box/config.json` 添加节点配置。

### Q: 如何重置服务？
A: 
```bash
# sing-box
ssh root@10.0.0.3 'systemctl stop sing-box && rm -rf /etc/sing-box && rm /usr/local/bin/sing-box'

# AdGuard Home
ssh root@10.0.0.4 'systemctl stop AdGuardHome && rm -rf /opt/AdGuardHome'

# 转换服务
ssh root@10.0.0.3 'systemctl stop clash-converter && rm -rf /opt/clash-converter'
```

---

## 📖 更多文档

- [详细配置说明](docs/CONFIG.md)
- [RouterOS 配置](routeros/generate-config.sh)
- [sing-box 官方文档](https://sing-box.sagernet.org)

---

## 📄 许可证

MIT License

---

## 🤝 贡献

欢迎 Issue 和 PR！

---

## 🙏 致谢

- [sing-box](https://github.com/SagerNet/sing-box) - 通用代理平台
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) - DNS 广告拦截
- [community-scripts](https://github.com/community-scripts/ProxmoxVE) - Proxmox VM 创建参考

---

**快速开始：**
```bash
git clone https://github.com/WinsPan/home-net.git
cd home-net
bash setup.sh
```
