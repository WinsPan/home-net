# AdGuard Home 详细配置指南

## 📋 目录

1. [初始化设置](#初始化设置)
2. [DNS 设置](#dns-设置)
3. [过滤规则配置](#过滤规则配置)
4. [高级功能](#高级功能)
5. [RouterOS 集成](#routeros-集成)
6. [常见问题](#常见问题)

---

## 🚀 初始化设置

### 1. 访问 Web 界面

安装完成后，访问 AdGuard Home：

```
http://10.0.0.4:3000
```

### 2. 初始化向导

#### 步骤 1：欢迎页面
- 点击 **"开始配置"**

#### 步骤 2：管理界面设置
```
管理界面 IP: 0.0.0.0 (所有接口)
管理界面端口: 3000
用户名: admin (自定义)
密码: ******** (设置强密码)
```

#### 步骤 3：DNS 服务器设置
```
DNS 服务器 IP: 0.0.0.0 (所有接口)
DNS 服务器端口: 53
```

#### 步骤 4：完成初始化
- 点击 **"下一步"** → **"完成"**
- 使用设置的用户名密码登录

---

## 🌐 DNS 设置

### 1. 上游 DNS 服务器

**路径：** 设置 → DNS 设置 → 上游 DNS 服务器

**推荐配置（中国大陆）：**

```
# 国内 DNS（DoH/DoT）
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
tls://dns.alidns.com
tls://dot.pub

# 国际 DNS（备用）
https://1.1.1.1/dns-query
https://8.8.8.8/dns-query
```

**推荐配置（国际）：**

```
https://1.1.1.1/dns-query
https://1.0.0.1/dns-query
https://8.8.8.8/dns-query
https://8.8.4.4/dns-query
tls://1.1.1.1
tls://8.8.8.8
```

**配置说明：**
- ✅ 使用加密 DNS（DoH/DoT）保护隐私
- ✅ 多个上游服务器提供冗余
- ✅ 混合使用国内外 DNS 提高解析速度

### 2. Bootstrap DNS 服务器

**作用：** 用于解析加密 DNS 服务器的域名

**推荐配置：**

```
223.5.5.5
119.29.29.29
8.8.8.8
1.1.1.1
```

### 3. DNS 服务设置

**速率限制：**
```
速率限制: 30 (每秒查询数)
```
防止 DNS 洪水攻击

**启用选项：**
- ✅ **启用 EDNS 客户端子网**：提高 CDN 解析准确性
- ✅ **启用 DNSSEC**：验证 DNS 响应真实性
- ✅ **禁用 IPv6**：如果你的网络不支持 IPv6（可选）

**缓存设置：**
```
缓存大小: 4194304 字节 (4MB)
最小缓存 TTL: 0 秒
最大缓存 TTL: 86400 秒 (24小时)
```

---

## 🛡️ 过滤规则配置

### 1. DNS 封锁清单（推荐规则）

**路径：** 过滤器 → DNS 封锁清单 → 添加阻止列表

#### 中文优化规则（推荐）⭐

```
名称: anti-AD
URL: https://anti-ad.net/easylist.txt
描述: 国内广告过滤，命中率高

名称: AdGuard DNS filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
描述: AdGuard 官方规则

名称: AdGuard 中文规则
URL: https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_224_Chinese/filter.txt
描述: 中文网站优化

名称: CHN: anti-AD
URL: https://anti-ad.net/adguard.txt
描述: anti-AD AdGuard 版本
```

#### 国际通用规则

```
名称: EasyList
URL: https://easylist-downloads.adblockplus.org/easylist.txt
描述: 国际通用广告规则

名称: EasyPrivacy
URL: https://easylist-downloads.adblockplus.org/easyprivacy.txt
描述: 隐私保护规则

名称: Peter Lowe's List
URL: https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=0
描述: 恶意软件/广告/跟踪器
```

#### 其他推荐规则

```
名称: Fanboy Annoyances
URL: https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt
描述: 移除页面烦人元素

名称: Malware Domains
URL: https://raw.githubusercontent.com/RPiList/specials/master/Blocklists/Malware
描述: 恶意软件域名
```

### 2. DNS 允许清单（白名单）

**路径：** 过滤器 → DNS 允许清单

**常用白名单：**

```
# 微软服务
*.microsoft.com
*.windows.com
*.msftconnecttest.com

# Apple 服务
*.apple.com
*.icloud.com
*.mzstatic.com

# Google 服务
*.google.com
*.googleapis.com
*.gstatic.com

# 视频平台
*.youtube.com
*.googlevideo.com
*.bilibili.com

# 支付服务
*.alipay.com
*.wechat.com
*.qq.com

# CDN
*.cloudflare.com
*.cdn.cloudflare.net
```

### 3. 自定义过滤规则

**路径：** 过滤器 → 自定义过滤规则

**语法：**

```
# 阻止域名
||ad.example.com^

# 阻止所有子域名
||ads.example.com^

# 允许域名（白名单）
@@||safe.example.com^

# 正则表达式
/^ad[0-9]+\.example\.com$/

# 注释
# 这是注释

# HOSTS 格式
0.0.0.0 ad.example.com
127.0.0.1 tracker.example.com
```

**示例规则：**

```
# 常见广告域名
||googleads.g.doubleclick.net^
||pagead2.googlesyndication.com^
||adservice.google.com^
||stats.g.doubleclick.net^

# 中国广告联盟
||union.360.cn^
||tanx.com^
||alimama.cn^

# 追踪器
||google-analytics.com^
||umeng.com^
||baidu.com/hm.js
```

---

## ⚙️ 高级功能

### 1. DNS 重写

**路径：** 过滤器 → DNS 重写

**用途：** 自定义域名解析

**示例：**

```
域名: nas.home → IP: 192.168.1.100
域名: router.home → IP: 10.0.0.2
域名: *.local → IP: 192.168.1.1
```

**常用场景：**
- 内网设备友好域名
- 屏蔽特定域名（指向 0.0.0.0）
- CDN 优化

### 2. DHCP 服务器

**路径：** 设置 → DHCP 设置

**⚠️ 注意：** 如果 RouterOS 已经提供 DHCP，不要启用此功能

**配置：**
```
网关 IP: 10.0.0.2
子网掩码: 255.255.255.0
DHCP 范围: 10.0.0.100 - 10.0.0.200
租约时间: 86400 秒 (24小时)
```

### 3. 客户端设置

**路径：** 设置 → 客户端设置

**持久客户端：** 为特定设备设置规则

**示例：**
```
名称: Kids-iPad
MAC: AA:BB:CC:DD:EE:FF
标签: 儿童设备
使用以下上游: 安全DNS
启用安全浏览: ✅
启用家长控制: ✅
```

### 4. 查询日志

**路径：** 查询日志

**功能：**
- 查看所有 DNS 查询
- 分析被拦截的请求
- 手动添加到白名单/黑名单
- 查看客户端查询统计

**设置：**
```
日志保留: 24 小时
匿名化客户端 IP: 根据隐私需求
```

### 5. 统计信息

**路径：** 仪表盘

**显示内容：**
- 查询总数
- 被拦截请求百分比
- 最常查询的域名
- 最常被拦截的域名
- 客户端统计

---

## 🔗 RouterOS 集成

### 方案 1：作为主 DNS（推荐）

**RouterOS 配置：**

```routeros
# 1. 设置 RouterOS 使用 AdGuard Home
/ip dns
set servers=10.0.0.4,223.5.5.5,8.8.8.8
set allow-remote-requests=yes

# 2. DHCP 分配 DNS
/ip dhcp-server network
set [find] dns-server=10.0.0.4,223.5.5.5

# 3. DNS 劫持（可选，强制所有设备使用）
/ip firewall nat
add chain=dstnat \
    protocol=udp \
    dst-port=53 \
    dst-address=!10.0.0.4 \
    action=dst-nat \
    to-addresses=10.0.0.4 \
    comment="Redirect DNS to AdGuard Home"

add chain=dstnat \
    protocol=tcp \
    dst-port=53 \
    dst-address=!10.0.0.4 \
    action=dst-nat \
    to-addresses=10.0.0.4 \
    comment="Redirect DNS to AdGuard Home"
```

### 方案 2：带健康检查的故障转移

**RouterOS 配置：**

```routeros
# AdGuard Home 健康检查
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
```

详细配置请参考：[DEPLOY.md](DEPLOY.md)

---

## 🧪 测试验证

### 1. 测试 DNS 解析

```bash
# 在客户端测试
nslookup google.com 10.0.0.4
nslookup baidu.com 10.0.0.4

# 应该返回正确的 IP 地址
```

### 2. 测试广告拦截

访问测试网站：
```
http://testingadguard.com/
```

应该显示：**"AdGuard is enabled"**

### 3. 测试 DNSSEC

```bash
dig +dnssec cloudflare.com @10.0.0.4
```

应该在响应中看到 `ad` 标志

### 4. 查看统计

访问 AdGuard Home 仪表盘，查看：
- 拦截率（通常 10-30%）
- 查询数量
- 被拦截的域名

---

## 🔧 性能优化

### 1. 缓存优化

```
缓存大小: 8388608 字节 (8MB)
最大缓存 TTL: 86400 秒
```

### 2. 上游 DNS 并行查询

**路径：** 设置 → DNS 设置

- ✅ **启用并行查询**：同时查询所有上游，使用最快响应
- ✅ **使用最快 IP 地址**：对同一域名的多个 IP 进行测速

### 3. 优化规则

- 定期更新规则（每天自动）
- 移除重复规则
- 使用本地规则文件（减少网络请求）

---

## 🚨 常见问题

### 1. 无法访问某些网站

**原因：** 被规则误拦截

**解决：**
1. 查看 **查询日志**，找到被拦截的域名
2. 点击域名旁的 **"添加到白名单"**
3. 或手动添加到 **DNS 允许清单**

### 2. 视频广告还在

**原因：** 视频广告通常从内容服务器加载

**解决：**
- AdGuard Home 只能拦截 DNS 查询
- 视频内嵌广告需要浏览器插件（如 uBlock Origin）
- 部分平台（如 YouTube）广告无法通过 DNS 拦截

### 3. Apple 设备无法连接

**原因：** Apple 服务被误拦截

**白名单：**
```
*.apple.com
*.icloud.com
*.apple-cloudkit.com
*.push.apple.com
*.appattest.apple.com
```

### 4. 微信/支付宝无法使用

**白名单：**
```
*.qq.com
*.wechat.com
*.weixin.qq.com
*.alipay.com
*.alipayobjects.com
```

### 5. DNS 解析慢

**检查：**
1. 上游 DNS 响应时间（仪表盘 → DNS 查询）
2. 规则数量（过多会影响性能）
3. 网络连接到上游 DNS

**优化：**
- 使用地理位置接近的 DNS 服务器
- 启用并行查询
- 增加缓存大小

### 6. 管理界面无法访问

**检查：**
```bash
# 查看服务状态
systemctl status AdGuardHome

# 查看日志
journalctl -u AdGuardHome -f

# 检查端口
netstat -tulpn | grep 3000
```

**重启服务：**
```bash
systemctl restart AdGuardHome
```

---

## 📊 推荐配置总结

### 最小配置（快速开始）

```yaml
上游 DNS:
  - https://dns.alidns.com/dns-query
  - https://1.1.1.1/dns-query

过滤规则:
  - anti-AD (https://anti-ad.net/easylist.txt)
  - AdGuard DNS filter

设置:
  - 启用 DNSSEC: ✅
  - 启用 EDNS: ✅
  - 速率限制: 30
```

### 完整配置（最佳实践）

```yaml
上游 DNS:
  - https://dns.alidns.com/dns-query
  - https://doh.pub/dns-query
  - https://1.1.1.1/dns-query
  - https://8.8.8.8/dns-query

Bootstrap DNS:
  - 223.5.5.5
  - 119.29.29.29
  - 8.8.8.8

过滤规则:
  - anti-AD
  - AdGuard DNS filter
  - AdGuard 中文规则
  - EasyList
  - EasyPrivacy
  - Malware Domains

白名单:
  - *.microsoft.com
  - *.apple.com
  - *.google.com
  - *.qq.com
  - *.alipay.com

设置:
  - 启用 DNSSEC: ✅
  - 启用 EDNS: ✅
  - 并行查询: ✅
  - 速率限制: 30
  - 缓存: 8MB
  - 日志保留: 24小时
```

---

## 🔄 维护建议

### 日常维护

- **每周查看统计**：了解拦截效果
- **检查查询日志**：发现异常查询
- **更新规则**：AdGuard Home 自动每天更新

### 定期维护

- **每月检查白名单**：移除不需要的条目
- **每季度优化规则**：移除失效规则
- **备份配置**：导出配置文件

### 备份配置

**导出配置：**
```bash
# 在 AdGuard Home VM 上
cd /opt/AdGuardHome
tar -czf ~/adguardhome-backup-$(date +%Y%m%d).tar.gz AdGuardHome.yaml
```

**恢复配置：**
```bash
systemctl stop AdGuardHome
cd /opt/AdGuardHome
tar -xzf ~/adguardhome-backup-YYYYMMDD.tar.gz
systemctl start AdGuardHome
```

---

## 📚 相关文档

- [AdGuard Home 官方文档](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [RouterOS 集成配置](DEPLOY.md)
- [故障排查指南](DEPLOY.md#常见问题)

---

**🎉 配置完成后，享受无广告的清爽网络体验！**

