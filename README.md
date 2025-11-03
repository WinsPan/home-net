# BoomDNS

基于 Proxmox VE 的自动化脚本集合，用于快速部署 mihomo 代理服务。

## 📖 项目简介

BoomDNS 提供了一套自动化脚本，可以在 Proxmox VE 环境中一键创建 Debian LXC 容器并自动安装配置 mihomo (Clash Meta 内核)。项目设计参考了 [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) 的架构风格。

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

### 部署 mihomo 代理服务

在 Proxmox VE 主机上执行以下命令：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)
```

脚本会自动创建容器并安装 mihomo，完成后可以通过 Web 面板 (Yacd) 管理代理。

**详细文档**: 查看 [快速入门指南](docs/QUICKSTART.md) 和 [使用文档](docs/USAGE.md)

### 部署 AdGuard Home 广告过滤

在 Proxmox VE 主机上执行以下命令：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-adguardhome-lxc.sh)
```

脚本会自动创建容器并安装 AdGuard Home，访问 `http://<容器IP>:3000` 完成初始化配置。

**配置规则**: 参考 [AdGuard Home 规则文档](docs/adguardhome-rules.md)

### 完整方案（推荐）

1. **部署 mihomo** - 提供代理服务
2. **部署 AdGuard Home** - 提供广告过滤
3. **配置 AdGuard 上游 DNS** - 指向 mihomo 的 DNS 端口 (mihomo 容器IP:53)
4. **配置设备 DNS** - 指向 AdGuard Home (AdGuard 容器IP:53)

这样可以实现：**广告过滤 + 智能分流 + DNS 无污染**

## 📁 项目结构

```
boomdns/
├── README.md                          # 项目说明文档
├── scripts/
│   ├── create-mihomo-lxc.sh          # ⭐ mihomo 部署脚本
│   ├── create-adguardhome-lxc.sh     # ⭐ AdGuard Home 部署脚本
│   ├── ct/
│   │   └── mihomo.sh                 # CT 容器脚本
│   ├── install/
│   │   └── mihomo-install.sh         # mihomo 安装脚本
│   └── misc/
│       ├── update-mihomo.sh          # mihomo 更新脚本
│       └── setup-adguard-rules.sh    # AdGuard 规则配置
└── docs/
    ├── QUICKSTART.md                  # 快速入门指南
    ├── USAGE.md                       # 详细使用文档
    ├── adguardhome-rules.md           # AdGuard 规则配置
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
