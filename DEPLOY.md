# 部署指南

## 🏗️ 架构说明

### 核心设计

```
                        ┌─────────────────────────────────┐
                        │  RouterOS (10.0.0.2)           │
                        │  主路由 - 永远在线              │
                        │  ✓ DNS故障转移                  │
                        │  ✓ 代理故障转移                 │
                        └─────────────────────────────────┘
                                  ↓
                        ┌─────────┴─────────┐
                        ↓                   ↓
            ┌───────────────────┐  ┌──────────────────┐
            │ AdGuard Home      │  │ sing-box         │
            │ (10.0.0.4)        │  │ (10.0.0.3)       │
            │ DNS + 去广告      │  │ 代理服务         │
            │ ✓ 故障→公共DNS    │  │ ✓ 可选使用       │
            └───────────────────┘  └──────────────────┘
                                          ↑
                                          │ 订阅配置
                                          │
                                   ┌──────────────────┐
                                   │ Sub-Store        │
                                   │ (10.0.0.5)       │
                                   │ 订阅转换         │
                                   │ ✓ 可选部署       │
                                   └──────────────────┘
```

### 关键特性

✅ **RouterOS 是主路由**
- 所有流量都经过 RouterOS
- RouterOS 永远不会因为 sing-box 或 AdGuard Home 故障而断网

✅ **DNS 去广告（AdGuard Home）**
- 默认使用 AdGuard Home 过滤广告
- AdGuard Home 故障时，自动切换到公共 DNS (223.5.5.5, 8.8.8.8)
- 30秒健康检查，自动故障转移

✅ **代理服务（sing-box）- 可选**
- 方式1: 客户端手动配置代理（推荐）
  - 灵活可控，故障时关闭代理即可
- 方式2: RouterOS 透明代理（高级）
  - 自动代理，带故障转移路由

✅ **订阅转换（Sub-Store）- 可选**
- Docker 部署，轻量级
- Web UI 管理订阅
- 转换 Clash → sing-box
- 多订阅合并和高级规则

✅ **故障不影响上网**
- AdGuard Home 故障 → DNS 自动切换到公共 DNS
- sing-box 故障 → 关闭代理或走直连路由
- Sub-Store 故障 → 不影响已配置的 sing-box
- RouterOS 主路由始终工作正常

---

## 📋 IP地址规划

```
RouterOS (主路由):  10.0.0.2  ← 核心，永远在线
sing-box (代理):    10.0.0.3  ← 可选，故障不影响上网
AdGuard Home (DNS): 10.0.0.4  ← 去广告，有故障转移
Sub-Store (转换):   10.0.0.5  ← 可选，订阅管理和转换
```

**VM 配置建议：**
- RouterOS: 专用路由器设备或 VM (512MB+)
- sing-box VM: 1核 512MB 即可
- AdGuard Home VM: 1核 512MB 即可
- Sub-Store VM: 1核 256MB 即可（Docker 部署）

---

## 🚀 部署流程

### 第一步：创建VM（在PVE节点执行）

```bash
# 1. 创建 sing-box VM
bash create-vm.sh

# 配置：
VM 名称: sing-box
VMID: 101
CPU: 2核
内存: 2048 MB
磁盘: 10 GB
IP: 10.0.0.3/24
网关: 10.0.0.2
root密码: ******

# 2. 创建 AdGuard Home VM
bash create-vm.sh

# 配置：
VM 名称: adguardhome
VMID: 102
CPU: 1核
内存: 512 MB
磁盘: 5 GB
IP: 10.0.0.4/24
网关: 10.0.0.2
root密码: ******

# 3. （可选）创建 Sub-Store VM
bash create-vm.sh

# 配置：
VM 名称: substore
VMID: 103
CPU: 1核
内存: 512 MB
磁盘: 5 GB
IP: 10.0.0.5/24
网关: 10.0.0.2
root密码: ******
```

### 第二步：（可选）部署 Sub-Store（订阅转换服务）

**如果订阅是 Clash 格式，需要先部署 Sub-Store 进行转换**

```bash
# 1. SSH 登录 Sub-Store VM
ssh root@10.0.0.5

# 2. 一键部署（Docker 版）
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-substore-docker.sh | bash

# 3. 访问 Web UI
浏览器打开: http://10.0.0.5:3001

# 4. 首次访问会显示 API 路径
⚠️ **重要：请保存 API 路径**
- Sub-Store 会自动生成一个随机的 API 路径（如: `/CKg3abstVnOeRpm1aB5G`）
- 这个路径用于保护 API 端点，防止未授权访问
- 如果忘记路径，可以在 VM 上运行: `cat /opt/sub-store/.backend_path`

# 5. 配置订阅转换
- 点击 "订阅" → "+" 添加 Clash 订阅源
- 点击 "集合" → "+" 创建订阅集合
- 选择输出格式: sing-box
- 复制生成的订阅链接（类似: http://10.0.0.5:3001/download/collection/xxx）
```

### 第三步：安装 sing-box（在 sing-box VM 执行）

**重要：订阅必须是 sing-box 格式**

**方案 A：直接使用 sing-box 订阅**

```bash
# SSH登录
ssh root@10.0.0.3

# 一键安装
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash

# 输入 sing-box 格式订阅地址
```

**方案 B：使用 Sub-Store 转换后的订阅**

```bash
# SSH登录
ssh root@10.0.0.3

# 使用 Sub-Store 生成的订阅链接
SUB_URL="http://10.0.0.5:3001/download/collection/你的集合名称" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh)"
```

### 第四步：安装 AdGuard Home（在 AdGuard Home VM 执行）

```bash
# SSH登录
ssh root@10.0.0.4

# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh -o install.sh

# 运行安装
bash install.sh

# 完成后访问
http://10.0.0.4:3000
```

---

## ⚙️ AdGuard Home 配置

### 初始化设置

1. **访问管理界面**
   ```
   http://10.0.0.4:3000
   ```

2. **创建管理员账号**
   - 用户名: admin
   - 密码: （设置强密码）

3. **端口配置**
   - DNS端口: 53 (默认)
   - Web端口: 3000 (默认)

### 上游DNS配置

推荐配置（国内优先）：
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
223.5.5.5
```

### 过滤规则

推荐添加：
```
名称: anti-AD
URL: https://anti-ad.net/easylist.txt

名称: AdGuard DNS filter
(内置，勾选启用)

名称: EasyList China
(内置，勾选启用)
```

---

## 🌐 RouterOS 配置（关键！）

> **重要：RouterOS 是主路由，所有配置都包含故障转移机制，确保 sing-box 或 AdGuard Home 故障时不影响上网。**

---

### 架构说明

```
客户端
  ↓
RouterOS (10.0.0.2) ← 主路由，永远在线
  ↓
  ├→ DNS: AdGuard Home (10.0.0.4) ← 去广告，有故障转移
  └→ 代理: sing-box (10.0.0.3) ← 可选，客户端手动配置
```

---

### 一、DNS配置（带故障转移）⭐

**确保 AdGuard Home 故障时自动切换到公共DNS**

```routeros
# 1. 设置路由器自身DNS（主用 AdGuard Home）
/ip dns
set servers=10.0.0.4,223.5.5.5,8.8.8.8
set allow-remote-requests=yes

# 2. 设置DHCP分配的DNS（客户端使用）
/ip dhcp-server network
set [find] dns-server=10.0.0.4,223.5.5.5

# 说明：
# - servers 列表中，优先使用第一个DNS
# - 如果第一个DNS (10.0.0.4) 无响应，自动使用后面的DNS
# - 这样即使 AdGuard Home 故障，DNS依然可用
```

---

### 二、DNS 健康检查（推荐）⭐⭐

**主动监控 AdGuard Home，故障时自动切换**

```routeros
# 创建 AdGuard Home 健康检查
/tool netwatch
add host=10.0.0.4 \
    interval=30s \
    timeout=5s \
    comment="AdGuard Home Health Check" \
    down-script={
        :log warning "AdGuard Home DOWN! Switching to public DNS"
        /ip dns set servers=223.5.5.5,8.8.8.8
        /ip dhcp-server network set [find] dns-server=223.5.5.5,8.8.8.8
    } \
    up-script={
        :log info "AdGuard Home UP! Restoring AdGuard DNS"
        /ip dns set servers=10.0.0.4,223.5.5.5,8.8.8.8
        /ip dhcp-server network set [find] dns-server=10.0.0.4,223.5.5.5
    }

# 说明：
# - 每30秒检查一次 AdGuard Home 是否在线
# - 故障时：切换到公共DNS (223.5.5.5, 8.8.8.8)
# - 恢复时：自动切回 AdGuard Home
# - 整个过程自动完成，用户无感知
```

---

### 三、sing-box 代理配置（可选）

> **说明：sing-box 代理是可选的，不影响基本上网功能**

#### 方式 1：客户端手动配置（推荐）⭐

**优点：灵活可控，不影响其他设备**

客户端设置代理：
```
HTTP/HTTPS 代理: 10.0.0.3:7890
SOCKS5 代理: 10.0.0.3:7890

# Windows: 设置 → 网络 → 代理
# macOS: 系统偏好设置 → 网络 → 高级 → 代理
# iOS/Android: WiFi设置 → 配置代理
```

即使 sing-box 故障，只需关闭代理设置即可正常上网。

#### 方式 2：RouterOS 透明代理（高级）

**优点：自动代理，无需客户端配置**  
**缺点：sing-box 故障时需要手动处理**

```routeros
# 1. 创建中国IP地址列表（直连）
/ip firewall address-list
add list=china address=10.0.0.0/8
add list=china address=172.16.0.0/12
add list=china address=192.168.0.0/16

# 2. 标记需要代理的流量（非中国IP）
/ip firewall mangle
add chain=prerouting \
    src-address=192.168.88.0/24 \
    dst-address-list=!china \
    protocol=tcp \
    dst-port=80,443 \
    action=mark-routing \
    new-routing-mark=proxy \
    comment="Mark traffic for sing-box proxy"

# 3. 创建代理路由（带健康检查）
/ip route
add dst-address=0.0.0.0/0 \
    gateway=10.0.0.3 \
    routing-mark=proxy \
    distance=1 \
    check-gateway=ping \
    comment="Route to sing-box"

# 4. 添加备用直连路由（sing-box故障时使用）
/ip route
add dst-address=0.0.0.0/0 \
    gateway=[WAN网关IP] \
    routing-mark=proxy \
    distance=2 \
    comment="Fallback direct route"

# 5. NAT配置
/ip firewall nat
add chain=srcnat \
    out-interface=[WAN接口] \
    action=masquerade

# 说明：
# - check-gateway=ping: 自动检测 sing-box 是否在线
# - distance=1/2: 优先使用 sing-box，故障时自动使用备用路由
# - 这样即使 sing-box 故障，流量会自动走直连
```

#### sing-box 健康检查（透明代理时使用）

```routeros
/tool netwatch
add host=10.0.0.3 \
    interval=30s \
    timeout=5s \
    comment="sing-box Health Check" \
    down-script={
        :log warning "sing-box DOWN! Traffic will use fallback route"
        # 路由会自动切换，无需额外操作
    } \
    up-script={
        :log info "sing-box UP! Proxy route restored"
    }
```

---

### 完整配置脚本（推荐配置）

```routeros
# ============================================
# RouterOS 完整配置（带故障转移）
# ============================================

# 1. DNS配置（AdGuard Home + 故障转移）
/ip dns
set servers=10.0.0.4,223.5.5.5,8.8.8.8
set allow-remote-requests=yes

/ip dhcp-server network
set [find] dns-server=10.0.0.4,223.5.5.5

# 2. AdGuard Home 健康检查
/tool netwatch
add host=10.0.0.4 \
    interval=30s \
    timeout=5s \
    comment="AdGuard Home Health Check" \
    down-script={
        :log warning "AdGuard Home DOWN! Switching to public DNS"
        /ip dns set servers=223.5.5.5,8.8.8.8
        /ip dhcp-server network set [find] dns-server=223.5.5.5,8.8.8.8
    } \
    up-script={
        :log info "AdGuard Home UP! Restoring AdGuard DNS"
        /ip dns set servers=10.0.0.4,223.5.5.5,8.8.8.8
        /ip dhcp-server network set [find] dns-server=10.0.0.4,223.5.5.5
    }

# 3. sing-box 健康检查（监控用）
/tool netwatch
add host=10.0.0.3 \
    interval=30s \
    timeout=5s \
    comment="sing-box Health Check"

# 完成！
# - DNS 自动故障转移：AdGuard Home 故障时自动切换到公共DNS
# - 代理可选：客户端手动配置代理，或者使用透明代理
# - 即使两个服务都故障，RouterOS 主路由仍然正常工作
```

---

### 验证故障转移

#### 测试 AdGuard Home 故障转移

```bash
# 1. 停止 AdGuard Home
ssh root@10.0.0.4 'systemctl stop AdGuardHome'

# 2. 客户端测试DNS（应该仍然正常）
nslookup google.com

# 3. 查看 RouterOS 日志
# 应该看到：AdGuard Home DOWN! Switching to public DNS

# 4. 恢复 AdGuard Home
ssh root@10.0.0.4 'systemctl start AdGuardHome'

# 5. 查看 RouterOS 日志
# 应该看到：AdGuard Home UP! Restoring AdGuard DNS
```

#### 测试 sing-box 故障（如果使用透明代理）

```bash
# 1. 停止 sing-box
ssh root@10.0.0.3 'systemctl stop sing-box'

# 2. 客户端测试上网（应该仍然正常，走直连）
curl https://www.google.com

# 3. 恢复 sing-box
ssh root@10.0.0.3 'systemctl start sing-box'

# 4. 客户端测试（应该恢复走代理）
```

---

## 🧪 测试验证

### 测试sing-box代理

```bash
# 测试代理连接
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 应返回 HTTP/1.1 200 OK
```

### 测试AdGuard Home

```bash
# 测试DNS解析
nslookup google.com 10.0.0.4

# 测试广告拦截
nslookup ad.doubleclick.net 10.0.0.4
# 应返回 0.0.0.0
```

### 客户端测试

**Windows/Mac/Linux:**
```bash
# 设置系统代理
HTTP代理: 10.0.0.3:7890
SOCKS5代理: 10.0.0.3:7890

# 或使用命令行
export http_proxy=http://10.0.0.3:7890
export https_proxy=http://10.0.0.3:7890

curl https://www.google.com
```

---

## 🔧 服务管理

### sing-box

```bash
# SSH到sing-box VM
ssh root@10.0.0.3

# 查看状态
systemctl status sing-box

# 重启服务
systemctl restart sing-box

# 查看日志
journalctl -u sing-box -f

# 编辑配置
nano /etc/sing-box/config.json
systemctl restart sing-box
```

### AdGuard Home

```bash
# SSH到AdGuard Home VM
ssh root@10.0.0.4

# 查看状态
systemctl status AdGuardHome

# 重启服务
systemctl restart AdGuardHome

# 查看日志
journalctl -u AdGuardHome -f
```

---

## 📊 端口说明

| 服务 | IP | 端口 | 协议 | 说明 |
|------|----|----|------|------|
| sing-box | 10.0.0.3 | 7890 | HTTP/SOCKS5 | 代理服务 |
| AdGuard Home | 10.0.0.4 | 53 | DNS | DNS服务 |
| AdGuard Home | 10.0.0.4 | 3000 | HTTP | Web管理 |

---

## 🔄 更新维护

### 更新sing-box

```bash
ssh root@10.0.0.3
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash
```

### 更新AdGuard Home

```bash
ssh root@10.0.0.4
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh | bash
```

### 更新订阅

```bash
# 方法1: 重新运行安装脚本
ssh root@10.0.0.3
bash install.sh

# 方法2: 手动转换（如果是Clash订阅）
python3 /opt/converter/convert.py "订阅URL" > /etc/sing-box/config.json
systemctl restart sing-box
```

---

## ❓ 常见问题

### Q: AdGuard Home 端口53被占用？
**A:** 安装脚本会自动停止 systemd-resolved 释放端口。

### Q: sing-box 无法连接？
**A:** 检查：
```bash
systemctl status sing-box
journalctl -u sing-box -n 50
```

### Q: Clash订阅转换失败？
**A:** 检查订阅URL是否正确，支持的协议：ss, vmess, trojan

### Q: 如何重置服务？
**A:**
```bash
# sing-box
systemctl stop sing-box
rm -rf /etc/sing-box
rm /usr/local/bin/sing-box

# AdGuard Home
systemctl stop AdGuardHome
rm -rf /opt/AdGuardHome
```

---

## 📁 配置文件位置

```
sing-box:
  配置: /etc/sing-box/config.json
  订阅: /etc/sing-box/.subscription
  GEO数据: /etc/sing-box/geoip.db, geosite.db

AdGuard Home:
  配置: /opt/AdGuardHome/AdGuardHome.yaml
  数据: /opt/AdGuardHome/data/

Clash转换器:
  脚本: /opt/converter/convert.py
```

---

## 🎯 使用场景

### 场景1：全局透明代理
配置RouterOS透明代理，所有设备自动使用代理+广告过滤。

### 场景2：手动代理
客户端手动设置代理 `10.0.0.3:7890`，享受分流和广告过滤。

### 场景3：仅DNS过滤
不使用代理，仅使用AdGuard Home DNS过滤广告。

---

## 📞 支持

- Issues: https://github.com/WinsPan/home-net/issues
- Docs: https://github.com/WinsPan/home-net

---

**🎉 部署完成！享受无广告的网络体验！**

