# BoomDNS

基于 Proxmox VE 的自动化脚本集合，用于快速部署 mihomo 代理服务。

## 📖 项目简介

BoomDNS 提供了一套完整的网络解决方案，包括：
- **mihomo** (Clash Meta) - 智能代理和国内外分流
- **AdGuard Home** - DNS级别广告过滤和隐私保护
- **RouterOS 集成** - 主路由配置方案

支持两种部署方式：
1. **LXC 容器**（轻量级）- 自动创建和配置
2. **虚拟机**（完整系统）- Debian 12 安装脚本

项目设计参考了 [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) 的架构风格。

## ✨ 特性

### 🔰 mihomo 代理服务
- 🚀 **一键部署**: 自动创建 Debian 12 LXC 容器
- 🔧 **自动配置**: 自动下载并安装最新版 mihomo
- 📦 **开箱即用**: 预配置 systemd 服务，容器重启自动启动
- 🌐 **多架构支持**: 支持 x86_64、ARM64、ARMv7
- 🎯 **交互式安装**: 友好的命令行交互界面
- 📊 **完善的管理**: 提供完整的服务管理和监控命令

### 🛡️ AdGuard Home 广告过滤
- 🚫 **广告拦截**: 强大的 DNS 级别广告过滤
- 🔒 **隐私保护**: 阻止追踪器和恶意软件
- 📋 **规则丰富**: 整合优质开源广告过滤规则
- 🎨 **易于管理**: Web 管理界面，实时统计
- ⚡ **性能优秀**: 低资源占用，快速响应
- 🌍 **全局生效**: 保护网络中所有设备

## 🎯 快速开始

### 前置要求

- Proxmox VE 8.x 或更高版本
- 具有 root 权限的 SSH 访问
- 互联网连接（用于下载模板和 mihomo）

### 🅰️ 方式一：LXC 容器部署（推荐）

#### 部署 mihomo 代理服务

在 Proxmox VE 主机上执行：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)
```

**详细文档**: [快速入门指南](docs/QUICKSTART.md) | [使用文档](docs/USAGE.md)

#### 部署 AdGuard Home 广告过滤

在 Proxmox VE 主机上执行：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-adguardhome-lxc.sh)
```

**配置规则**: [AdGuard Home 规则文档](docs/adguardhome-rules.md)

### 🅱️ 方式二：虚拟机部署（适合独立系统）

#### 在 Debian 12 虚拟机上安装 mihomo

```bash
# 在 mihomo VM 中执行
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh)
```

#### 在 Debian 12 虚拟机上安装 AdGuard Home

```bash
# 在 AdGuard Home VM 中执行
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh)
```

**完整部署指南**: [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) - 包含虚拟机创建、网络配置等详细步骤

### 完整方案（推荐）

1. **部署 mihomo** - 提供代理服务
2. **部署 AdGuard Home** - 提供广告过滤
3. **配置 AdGuard 上游 DNS** - 指向 mihomo 的 DNS 端口 (mihomo 容器IP:53)
4. **配置设备 DNS** - 指向 AdGuard Home (AdGuard 容器IP:53)

这样可以实现：**广告过滤 + 智能分流 + DNS 无污染**

### RouterOS (MikroTik) 主路由配置

如果您使用 RouterOS 作为主路由，需要配置 DNS 和 DHCP 设置。

#### 示例网络环境

假设您的网络规划如下：
```
RouterOS:        10.0.0.2
mihomo VM:       10.0.0.4
AdGuard Home VM: 10.0.0.5
```

**基础配置**：
```bash
# 设置路由器 DNS（指向 AdGuard Home）
/ip dns set servers=10.0.0.5

# 设置 DHCP 分发 DNS（让所有设备自动使用 AdGuard Home）
/ip dhcp-server network set [find] dns-server=10.0.0.5

# 为虚拟机绑定静态 IP（推荐）
/ip dhcp-server lease add address=10.0.0.4 mac-address=XX:XX:XX:XX:XX:XX comment="mihomo VM"
/ip dhcp-server lease add address=10.0.0.5 mac-address=XX:XX:XX:XX:XX:XX comment="AdGuard Home VM"
```

**数据流向**：
```
设备 → AdGuard Home (10.0.0.5) → mihomo (10.0.0.4) → 互联网
      ↓                           ↓
   过滤广告                    智能分流
```

**详细配置**: 参考 [RouterOS 配置指南](docs/ROUTEROS-CONFIG.md) 和 [完整部署指南](docs/DEPLOYMENT-GUIDE.md)

包含：
- DNS 劫持（强制）
- 透明代理
- 防火墙规则
- 访客网络配置
- 故障排查

## 📁 项目结构

```
boomdns/
├── README.md                          # 项目说明文档
├── LICENSE                            # MIT 许可证
├── CHANGELOG.md                       # 更新日志
├── CONTRIBUTING.md                    # 贡献指南
│
├── scripts/                           # 部署脚本
│   ├── create-mihomo-lxc.sh          # ⭐ LXC: mihomo 自动部署
│   ├── create-adguardhome-lxc.sh     # ⭐ LXC: AdGuard Home 自动部署
│   ├── install-mihomo-vm.sh          # ⭐ VM: mihomo 安装脚本
│   ├── install-adguardhome-vm.sh     # ⭐ VM: AdGuard Home 安装脚本
│   └── misc/                          # 工具脚本
│       ├── update-mihomo.sh          # mihomo 更新脚本
│       └── setup-adguard-rules.sh    # AdGuard 规则配置
│
└── docs/                              # 文档目录
    ├── QUICK-REFERENCE.md             # ⭐ 快速参考（推荐）
    ├── DEPLOYMENT-GUIDE.md            # ⭐ 完整部署指南（VM）
    ├── ROUTEROS-CONFIG.md             # RouterOS 配置指南
    ├── INTEGRATION-GUIDE.md           # 组合方案指南
    ├── adguardhome-rules.md           # AdGuard 规则配置
    ├── QUICKSTART.md                  # LXC 快速入门
    ├── USAGE.md                       # mihomo 详细使用
    └── config-examples.yaml           # mihomo 配置示例
```

## 🔧 配置说明

### mihomo 配置文件

配置文件位置: `/etc/mihomo/config.yaml`

```yaml
# 混合端口配置
mixed-port: 7890

# 允许局域网连接
allow-lan: true

# 外部控制器
external-controller: 0.0.0.0:9090

# DNS 配置
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

# 代理配置（需要自行添加）
proxies: []

# 代理组配置
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

# 规则配置
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```

### 添加代理节点

1. 进入容器：
```bash
pct enter <容器ID>
```

2. 编辑配置文件：
```bash
nano /etc/mihomo/config.yaml
```

3. 在 `proxies` 部分添加您的节点配置：
```yaml
proxies:
  - name: "节点1"
    type: ss
    server: example.com
    port: 8388
    cipher: aes-256-gcm
    password: password
```

4. 重启服务：
```bash
systemctl restart mihomo
```

## 📊 管理命令

### Proxmox 主机管理

```bash
# 查看所有容器
pct list

# 进入容器
pct enter <容器ID>

# 启动容器
pct start <容器ID>

# 停止容器
pct stop <容器ID>

# 重启容器
pct reboot <容器ID>

# 删除容器
pct destroy <容器ID>
```

### 容器内 mihomo 管理

```bash
# 查看服务状态
systemctl status mihomo

# 启动服务
systemctl start mihomo

# 停止服务
systemctl stop mihomo

# 重启服务
systemctl restart mihomo

# 查看实时日志
journalctl -u mihomo -f

# 查看最近日志
journalctl -u mihomo -n 100
```

## 🌐 访问服务

安装完成后，您可以通过以下方式访问 mihomo 服务：

### HTTP/SOCKS5 代理

```
HTTP 代理: http://<容器IP>:7890
SOCKS5 代理: socks5://<容器IP>:7890
```

### Web 控制面板

推荐使用 Yacd 面板管理 mihomo：

1. 访问 [http://yacd.metacubex.one](http://yacd.metacubex.one)
2. 输入控制器地址: `http://<容器IP>:9090`
3. 输入密钥（如果设置了 secret）

### DNS 服务

```
DNS 服务器: <容器IP>:53
```

## 🔄 更新 mihomo

### 手动更新

1. 进入容器：
```bash
pct enter <容器ID>
```

2. 运行更新命令：
```bash
# 下载最新版本
LATEST=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep tag_name | cut -d '"' -f 4)
ARCH=$(uname -m | sed 's/x86_64/linux-amd64/' | sed 's/aarch64/linux-arm64/')
wget -O /tmp/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/download/${LATEST}/mihomo-${ARCH}-${LATEST}.gz"

# 停止服务
systemctl stop mihomo

# 替换二进制文件
gunzip -c /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm /tmp/mihomo.gz

# 启动服务
systemctl start mihomo
```

## 🛠️ 故障排查

### 服务无法启动

```bash
# 查看详细错误日志
journalctl -u mihomo -n 50 --no-pager

# 检查配置文件语法
/usr/local/bin/mihomo -d /etc/mihomo -t
```

### 网络连接问题

```bash
# 检查端口监听
ss -tuln | grep -E '7890|9090|53'

# 测试代理连接
curl -x http://127.0.0.1:7890 https://www.google.com
```

### 容器无法访问

```bash
# 在 Proxmox 主机上检查容器状态
pct status <容器ID>

# 查看容器 IP
pct exec <容器ID> -- hostname -I

# 测试网络连接
ping <容器IP>
```

## 📚 参考资源

- [mihomo 官方文档](https://wiki.metacubex.one/)
- [Clash 配置文档](https://clash.wiki/)
- [Proxmox VE 文档](https://pve.proxmox.com/pve-docs/)
- [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证。

## ⚠️ 免责声明

本项目仅供学习和研究使用，请遵守当地法律法规。使用本项目所产生的一切后果由使用者自行承担。

## 🙏 致谢

- 感谢 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 项目
- 感谢 [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) 提供的项目结构参考
- 感谢所有贡献者

---

**如果这个项目对您有帮助，请给一个 ⭐ Star！**
