# BoomDNS

智能分流 + 广告过滤 + 容错保护的完整家庭网络解决方案

---

## 快速开始

### 环境要求
- Proxmox VE 8.0+
- 2 台 Debian 12 VM
- RouterOS 7.x

### IP 规划
| 设备 | IP | 功能 |
|------|---------|------|
| RouterOS | 10.0.0.2 | 网关 + DNS 劫持 |
| mihomo | 10.0.0.4 | 智能代理 |
| AdGuard Home | 10.0.0.5 | DNS 过滤 |

---

## 一键部署

### 1. 安装 mihomo

```bash
# 创建 Debian 12 VM (IP: 10.0.0.4)
# SSH 连接后执行：

curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh | sudo bash

# 选择配置类型：
# 1) 💡 智能配置（推荐） - 自动选择最优节点
# 2) 📝 基础配置 - 手动选择节点

# 输入机场订阅地址
# 等待安装完成
```

### 2. 安装 AdGuard Home

```bash
# 创建 Debian 12 VM (IP: 10.0.0.5)
# SSH 连接后执行：

curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh | sudo bash

# 访问 http://10.0.0.5:3000 完成初始化
```

### 3. 配置 RouterOS

```bash
# 连接 RouterOS 执行：

# DNS（带容错）
/ip dns set servers=10.0.0.5,223.5.5.5,119.29.29.29

# DHCP
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=ether1 address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.2 \
    dns-server=10.0.0.5,223.5.5.5,119.29.29.29

# DNS 劫持（可选）
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 to-addresses=10.0.0.5 comment="DNS Hijack"
```

### 4. 配置代理（二选一）

#### 方案一：设备手动设置（推荐）✅

在需要代理的设备上设置：
- HTTP 代理: `10.0.0.4:7890`
- SOCKS5 代理: `10.0.0.4:7891`

**Windows:** 设置 → 网络 → 代理  
**macOS:** 系统偏好设置 → 网络 → 代理  
**iOS/Android:** WiFi 设置 → 配置代理

**浏览器扩展（最方便）:**
- 安装 SwitchyOmega
- 配置代理服务器: `10.0.0.4:7890`

#### 方案二：透明代理（高级）🔧

全局生效，无需设备配置。

查看 [完整配置文档](docs/CONFIG.md#6-代理配置) 了解详细步骤。

完成！🎉

---

## 核心特性

### 💡 智能分流
- **Smart 策略** - 自动选择最快节点
- **负载均衡** - 多节点带宽叠加
- **故障转移** - 自动切换备用节点
- **地区分组** - 香港/新加坡/日本/美国

### 🛡️ 广告过滤
- **DNS 级别拦截** - 全设备生效
- **多规则源** - Anti-AD + EasyList
- **自动更新** - 规则定时同步
- **白名单** - 防止误拦

### 🔄 容错机制
- **多 DNS 备份** - 服务故障自动切换
- **健康检查** - RouterOS 自动监控
- **零中断** - 任何服务挂掉都不影响上网

---

## 文档

- **[完整配置](docs/CONFIG.md)** - mihomo + AdGuard Home + RouterOS 配置指南
- **[RouterOS](docs/ROUTEROS.md)** - RouterOS 详细配置

---

## 网络架构

```
客户端设备
    ↓
RouterOS (10.0.0.2)
    ↓ DNS劫持 + 容错
AdGuard Home (10.0.0.5)
    ↓ 广告过滤
mihomo (10.0.0.4)
    ↓ 智能分流
互联网
```

**工作流程：**
1. 客户端发起请求 → RouterOS
2. DNS 查询 → AdGuard Home 过滤广告
3. 代理请求 → mihomo 智能分流
4. 到达互联网

**容错流程：**
- AdGuard Home 故障 → 自动使用备用 DNS (223.5.5.5)
- mihomo 故障 → DNS 直连，失去分流功能
- 任何故障 → 上网不中断

---

## 管理维护

### 查看状态

```bash
# mihomo
systemctl status mihomo
journalctl -u mihomo -f

# AdGuard Home
systemctl status AdGuardHome
journalctl -u AdGuardHome -f
```

### 更新服务

```bash
# mihomo
/opt/mihomo/update-mihomo.sh

# AdGuard Home
# Web 界面 → 设置 → 检查更新
```

### Web 管理

- **mihomo**: `http://10.0.0.4:9090`
- **AdGuard Home**: `http://10.0.0.5`

---

## 故障排查

### 无法上网
```bash
# 1. 检查 DNS
nslookup baidu.com

# 2. 检查 RouterOS DNS
/ip dns print

# 3. 临时禁用 DNS 劫持
/ip firewall nat disable [find comment~"DNS"]
```

### 广告未拦截
```bash
# 1. 检查 AdGuard Home 规则
# Web 界面 → 过滤器 → 更新

# 2. 清除客户端 DNS 缓存
ipconfig /flushdns  # Windows
sudo dscacheutil -flushcache  # macOS
```

### 代理不工作
```bash
# 1. 检查 mihomo 状态
systemctl status mihomo

# 2. 测试代理
curl -x http://10.0.0.4:7890 https://www.google.com -I

# 3. 查看日志
journalctl -u mihomo -n 50
```

---

## 性能优化

**mihomo** - 开启持久化
```yaml
profile:
  store-selected: true
  store-fake-ip: true
```

**AdGuard Home** - 减少日志
- 保留时间：24 小时

**RouterOS** - 优化缓存
```bash
/ip dns set cache-size=10240 cache-max-ttl=1d
/ip firewall connection tracking set tcp-established-timeout=1d
```

---

## 技术栈

- **Proxmox VE** - 虚拟化平台
- **Debian 12** - 操作系统
- **mihomo** - Clash Meta 内核
- **AdGuard Home** - DNS 服务器
- **RouterOS** - 网关路由器

---

## 许可

MIT License

---

## 贡献

欢迎提交 Issue 和 PR！

查看 [贡献指南](CONTRIBUTING.md)

---

## 更新日志

查看 [CHANGELOG.md](CHANGELOG.md)

---

**重要提示：**
- 首次部署请仔细阅读 [完整配置文档](docs/CONFIG.md)
- 机场订阅地址必须替换为实际地址
- 建议定期备份配置文件
- 遇到问题优先查看日志

**快速链接：**
- [配置文档](docs/CONFIG.md)
- [RouterOS 配置](docs/ROUTEROS.md)
- [GitHub Issues](https://github.com/WinsPan/home-net/issues)

---

⭐ 如果这个项目对你有帮助，欢迎 Star！
