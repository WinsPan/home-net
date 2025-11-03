# 使用指南 - mihomo 详细配置

> ⚠️ **注意**: 本文档主要介绍 mihomo 的配置和使用。
> 
> 完整部署指南请查看：
> - [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - 针对您的网络环境（10.0.0.x） ⭐ 推荐
> - [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - 虚拟机完整部署步骤

本文档提供 mihomo 代理服务的详细配置说明。

## 🚀 部署方式

### 方式一：虚拟机部署（适合 10.0.0.x 网络）

在 Debian VM 中执行：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh)
```

### 方式二：LXC 容器部署

在 Proxmox VE 主机执行：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)
```

## 📝 安装流程详解

### 1. 容器配置

脚本启动后会要求您输入以下信息：

#### 容器 ID
```
建议的容器 ID: 100
请输入容器 ID (直接回车使用 100): 
```
- 直接回车使用建议的 ID
- 或输入自定义的 ID（100-999999）

#### 容器名称
```
请输入容器名称 (默认: mihomo): 
```
- 默认名称为 `mihomo`
- 可自定义，如 `mihomo-proxy`、`clash-meta` 等

#### 存储位置
```
请选择存储位置 (默认: local-lvm): 
```
- 查看可用的存储池
- 常见选项：`local-lvm`、`local-zfs`、`local-btrfs`

#### 资源配置
```
请输入磁盘大小 (GB, 默认: 4): 
请输入 CPU 核心数 (默认: 2): 
请输入内存大小 (MB, 默认: 1024): 
```
推荐配置：
- **最小配置**: 2GB 磁盘 / 1 核 / 512MB 内存
- **推荐配置**: 4GB 磁盘 / 2 核 / 1024MB 内存
- **高负载配置**: 8GB 磁盘 / 4 核 / 2048MB 内存

#### 网络配置
```
网络配置选项:
1) DHCP (自动获取 IP)
2) 静态 IP
请选择 (1/2, 默认: 1): 
```

**选择 DHCP (选项 1)**：
- 容器自动从路由器获取 IP
- 适合大多数家庭网络环境

**选择静态 IP (选项 2)**：
```
请输入静态 IP (例如: 192.168.1.100/24): 192.168.1.100/24
请输入网关 (例如: 192.168.1.1): 192.168.1.1
```
- 适合需要固定 IP 的场景
- IP 格式：`IP地址/子网掩码位数`

#### Root 密码
```
请输入 root 密码: 
```
- 设置容器的 root 用户密码
- 用于后续 SSH 登录或控制台访问

### 2. 自动安装过程

配置完成后，脚本会自动执行：

1. ✅ 检查并下载 Debian 12 模板
2. ✅ 创建 LXC 容器
3. ✅ 启动容器
4. ✅ 更新系统软件包
5. ✅ 安装必要依赖
6. ✅ 下载最新版 mihomo
7. ✅ 创建配置文件
8. ✅ 配置 systemd 服务
9. ✅ 启动 mihomo 服务

整个过程大约需要 3-5 分钟，取决于网络速度。

## 🔧 配置 mihomo

### 基础配置

1. **进入容器**：
```bash
pct enter <容器ID>
```

2. **编辑配置文件**：
```bash
nano /etc/mihomo/config.yaml
```

3. **添加代理节点**：

在 `proxies` 部分添加节点配置：

**Shadowsocks 示例**：
```yaml
proxies:
  - name: "SS-HK"
    type: ss
    server: hk.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "your-password"
```

**VMess 示例**：
```yaml
proxies:
  - name: "VMess-US"
    type: vmess
    server: us.example.com
    port: 443
    uuid: "your-uuid"
    alterId: 0
    cipher: auto
    tls: true
```

**Trojan 示例**：
```yaml
proxies:
  - name: "Trojan-JP"
    type: trojan
    server: jp.example.com
    port: 443
    password: "your-password"
    sni: jp.example.com
```

4. **配置代理组**：
```yaml
proxy-groups:
  - name: "手动选择"
    type: select
    proxies:
      - SS-HK
      - VMess-US
      - Trojan-JP
      - DIRECT

  - name: "自动选择"
    type: url-test
    proxies:
      - SS-HK
      - VMess-US
      - Trojan-JP
    url: 'http://www.gstatic.com/generate_204'
    interval: 300

  - name: "负载均衡"
    type: load-balance
    proxies:
      - SS-HK
      - VMess-US
      - Trojan-JP
    url: 'http://www.gstatic.com/generate_204'
    interval: 300
```

5. **配置规则**：
```yaml
rules:
  # 局域网直连
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  
  # 常用网站规则
  - DOMAIN-SUFFIX,google.com,手动选择
  - DOMAIN-SUFFIX,youtube.com,手动选择
  - DOMAIN-SUFFIX,github.com,手动选择
  
  # 中国直连
  - GEOIP,CN,DIRECT
  
  # 其他走代理
  - MATCH,手动选择
```

6. **保存并重启服务**：
```bash
# 保存文件：Ctrl + O，回车
# 退出编辑：Ctrl + X

# 测试配置
/usr/local/bin/mihomo -d /etc/mihomo -t

# 重启服务
systemctl restart mihomo

# 查看状态
systemctl status mihomo
```

### 高级配置

#### 1. 启用 TUN 模式（透明代理）

编辑配置文件，添加：

```yaml
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
```

#### 2. 配置外部控制器密钥

```yaml
external-controller: 0.0.0.0:9090
secret: "your-secret-key"
```

#### 3. 配置自定义 DNS

```yaml
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.lan'
    - 'localhost.ptlogin2.qq.com'
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://1.1.1.1/dns-query
    - https://dns.google/dns-query
```

## 🌐 使用代理

### 浏览器配置

#### Chrome/Edge（使用 SwitchyOmega 插件）

1. 安装 SwitchyOmega 扩展
2. 添加新情景模式
3. 配置：
   - 代理协议：HTTP
   - 代理服务器：容器IP
   - 代理端口：7890

#### Firefox

1. 设置 → 网络设置 → 手动代理配置
2. HTTP 代理：容器IP，端口：7890
3. 同时用于 HTTPS
4. 勾选 "使用 SOCKS v5 代理 DNS"

### 系统代理

#### Linux/macOS

临时设置（仅当前终端）：
```bash
export http_proxy=http://<容器IP>:7890
export https_proxy=http://<容器IP>:7890
export all_proxy=socks5://<容器IP>:7890
```

永久设置（添加到 ~/.bashrc 或 ~/.zshrc）：
```bash
echo 'export http_proxy=http://<容器IP>:7890' >> ~/.bashrc
echo 'export https_proxy=http://<容器IP>:7890' >> ~/.bashrc
echo 'export all_proxy=socks5://<容器IP>:7890' >> ~/.bashrc
source ~/.bashrc
```

#### Windows

临时设置（PowerShell）：
```powershell
$env:HTTP_PROXY="http://<容器IP>:7890"
$env:HTTPS_PROXY="http://<容器IP>:7890"
```

永久设置：
1. 系统设置 → 网络和 Internet → 代理
2. 手动设置代理
3. 地址：容器IP，端口：7890

### Docker 配置

编辑 `/etc/docker/daemon.json`：
```json
{
  "proxies": {
    "http-proxy": "http://<容器IP>:7890",
    "https-proxy": "http://<容器IP>:7890",
    "no-proxy": "localhost,127.0.0.1"
  }
}
```

重启 Docker：
```bash
systemctl restart docker
```

## 📊 监控和管理

### Web 控制面板（Yacd）

1. 访问：[http://yacd.metacubex.one](http://yacd.metacubex.one)
2. 输入 API 地址：`http://<容器IP>:9090`
3. 如果设置了密钥，输入密钥

面板功能：
- 实时流量监控
- 切换代理节点
- 查看连接信息
- 测试延迟
- 管理规则

### 命令行监控

```bash
# 查看服务状态
systemctl status mihomo

# 实时日志
journalctl -u mihomo -f

# 查看连接数
ss -tuln | grep -E '7890|9090|53'

# 测试代理
curl -x http://127.0.0.1:7890 https://www.google.com -I
```

### RESTful API

```bash
# 获取配置信息
curl http://<容器IP>:9090/configs

# 切换代理节点
curl -X PUT http://<容器IP>:9090/proxies/PROXY \
  -H "Content-Type: application/json" \
  -d '{"name":"SS-HK"}'

# 获取代理延迟
curl http://<容器IP>:9090/proxies
```

## 🔧 维护操作

### 备份配置

```bash
# 在 Proxmox 主机上执行
pct exec <容器ID> -- tar czf /tmp/mihomo-backup.tar.gz /etc/mihomo
pct pull <容器ID> /tmp/mihomo-backup.tar.gz ./mihomo-backup.tar.gz
```

### 恢复配置

```bash
# 在 Proxmox 主机上执行
pct push <容器ID> ./mihomo-backup.tar.gz /tmp/mihomo-backup.tar.gz
pct exec <容器ID> -- tar xzf /tmp/mihomo-backup.tar.gz -C /
pct exec <容器ID> -- systemctl restart mihomo
```

### 更新 mihomo

参考 README.md 中的更新章节。

### 迁移容器

```bash
# 停止容器
pct stop <容器ID>

# 备份容器
vzdump <容器ID> --storage local --mode stop

# 在新主机上恢复
pct restore <新ID> /var/lib/vz/dump/vzdump-lxc-<容器ID>-*.tar.gz
```

## ❓ 常见问题

### Q: 无法访问代理？

A: 检查以下几点：
1. 容器是否正常运行：`pct status <容器ID>`
2. 服务是否运行：`pct exec <容器ID> -- systemctl status mihomo`
3. 防火墙是否阻止：检查 Proxmox 和容器的防火墙规则
4. 网络是否连通：`ping <容器IP>`

### Q: 配置修改后不生效？

A: 需要重启服务：
```bash
pct exec <容器ID> -- systemctl restart mihomo
```

### Q: 如何查看日志？

A: 使用以下命令：
```bash
pct exec <容器ID> -- journalctl -u mihomo -n 100
```

### Q: 如何设置开机自启？

A: 容器已配置开机自启，确认：
```bash
pct config <容器ID> | grep onboot
# 输出应该是: onboot: 1
```

## 📞 获取帮助

- 查看项目 Issue
- 阅读 mihomo 官方文档
- 加入社区讨论

---

更多信息请参考 [README.md](../README.md)

