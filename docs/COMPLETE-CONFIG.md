# 完整配置方案 - 分流 + 去广告 + 容错

**重要特性：当 mihomo 或 AdGuard Home 故障时，网络自动回退到直连模式，不影响上网**

## 网络架构

```
客户端设备
    ↓
RouterOS (10.0.0.2)
    ↓ (DNS)
AdGuard Home (10.0.0.5) ← 广告过滤 + DNS
    ↓ (上游DNS)
mihomo (10.0.0.4) ← 智能分流
    ↓
互联网
```

---

## 一、mihomo 完整配置

### 1. 配置文件：`/etc/mihomo/config.yaml`

```yaml
# ==================== 基础配置 ====================
port: 7890                 # HTTP 代理端口
socks-port: 7891          # SOCKS5 代理端口
mixed-port: 7890          # 混合端口
allow-lan: true           # 允许局域网连接
bind-address: "*"         # 绑定所有网卡
mode: rule                # 规则模式
log-level: info           # 日志级别
ipv6: false              # 关闭 IPv6（根据需要开启）
external-controller: 0.0.0.0:9090  # API 端口
secret: ""               # API 密钥（建议设置）

# ==================== DNS 配置 ====================
dns:
  enable: true
  listen: 0.0.0.0:1053    # DNS 监听端口
  ipv6: false             # 关闭 IPv6 DNS
  enhanced-mode: fake-ip  # fake-ip 模式
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    # 局域网域名
    - "*.lan"
    - "*.local"
    - "*.localdomain"
    # 路由器域名
    - "router.asus.com"
    - "routerlogin.net"
    - "my.router"
    - "*.routerlogin.com"
    # NTP 服务
    - "time.*.com"
    - "time.*.gov"
    - "ntp.*.com"
    - "*.time.edu.cn"
    - "*.ntp.org.cn"
    # 其他
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
  
  # 默认 DNS 服务器
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  
  # 主 DNS 服务器
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
    - 223.5.5.5
    - 119.29.29.29
  
  # 备用 DNS（国外）
  fallback:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
    - tls://8.8.8.8
    - tls://1.1.1.1
  
  # fallback 触发条件
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4
    domain:
      - '+.google.com'
      - '+.facebook.com'
      - '+.youtube.com'
      - '+.twitter.com'
      - '+.github.com'

# ==================== 代理提供者（订阅）====================
proxy-providers:
  # 替换为你的订阅地址
  my-subscription:
    type: http
    url: "https://your-subscription-url-here"  # ⚠️ 修改这里
    interval: 86400          # 24小时更新一次
    path: ./providers/my-subscription.yaml
    health-check:
      enable: true
      interval: 600          # 10分钟检查一次
      lazy: true            # 懒加载模式
      url: http://www.gstatic.com/generate_204

# ==================== 代理组 ====================
proxy-groups:
  # 节点选择
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "♻️ 自动选择"
      - "🇭🇰 香港节点"
      - "🇨🇳 台湾节点"
      - "🇸🇬 狮城节点"
      - "🇯🇵 日本节点"
      - "🇺🇸 美国节点"
      - "🇰🇷 韩国节点"
      - DIRECT
    use:
      - my-subscription
  
  # 自动选择（延迟最低）
  - name: "♻️ 自动选择"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
  
  # 地区分组
  - name: "🇭🇰 香港节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)港|hk|hongkong|hong kong"
  
  - name: "🇨🇳 台湾节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)台|tw|taiwan"
  
  - name: "🇸🇬 狮城节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)新加坡|坡|狮城|sg|singapore"
  
  - name: "🇯🇵 日本节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)日本|jp|japan"
  
  - name: "🇺🇸 美国节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)美|us|unitedstates|united states"
  
  - name: "🇰🇷 韩国节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - my-subscription
    filter: "(?i)韩|kr|korea"
  
  # 功能分组
  - name: "📲 电报消息"
    type: select
    proxies:
      - "🚀 节点选择"
      - "♻️ 自动选择"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
      - DIRECT
  
  - name: "🎥 Netflix"
    type: select
    proxies:
      - "🚀 节点选择"
      - "🇭🇰 香港节点"
      - "🇨🇳 台湾节点"
      - "🇸🇬 狮城节点"
      - "🇯🇵 日本节点"
      - "🇺🇸 美国节点"
  
  - name: "🎬 Disney+"
    type: select
    proxies:
      - "🚀 节点选择"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
      - "🇺🇸 美国节点"
  
  - name: "📹 YouTube"
    type: select
    proxies:
      - "🚀 节点选择"
      - "♻️ 自动选择"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
  
  - name: "🎵 Spotify"
    type: select
    proxies:
      - "🚀 节点选择"
      - "DIRECT"
  
  - name: "🎮 游戏平台"
    type: select
    proxies:
      - DIRECT
      - "🚀 节点选择"
      - "🇭🇰 香港节点"
      - "🇯🇵 日本节点"
  
  - name: "🍎 苹果服务"
    type: select
    proxies:
      - DIRECT
      - "🚀 节点选择"
      - "🇺🇸 美国节点"
  
  - name: "Ⓜ️ 微软服务"
    type: select
    proxies:
      - DIRECT
      - "🚀 节点选择"
  
  - name: "🌍 国外流量"
    type: select
    proxies:
      - "🚀 节点选择"
      - "♻️ 自动选择"
      - DIRECT
  
  - name: "🎯 国内流量"
    type: select
    proxies:
      - DIRECT
      - "🚀 节点选择"
  
  - name: "🛡️ 广告拦截"
    type: select
    proxies:
      - REJECT
      - DIRECT
  
  - name: "🐟 漏网之鱼"
    type: select
    proxies:
      - "🚀 节点选择"
      - "♻️ 自动选择"
      - DIRECT

# ==================== 规则集 ====================
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400
  
  icloud:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400
  
  apple:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400
  
  google:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400
  
  proxy:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400
  
  direct:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400
  
  private:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400
  
  gfw:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400
  
  telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400
  
  cncidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400
  
  lancidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

# ==================== 规则 ====================
rules:
  # 局域网直连
  - RULE-SET,private,DIRECT
  - RULE-SET,lancidr,DIRECT,no-resolve
  
  # 广告拦截
  - RULE-SET,reject,🛡️ 广告拦截
  
  # 流媒体
  - DOMAIN-SUFFIX,netflix.com,🎥 Netflix
  - DOMAIN-SUFFIX,netflix.net,🎥 Netflix
  - DOMAIN-SUFFIX,nflxext.com,🎥 Netflix
  - DOMAIN-SUFFIX,nflximg.com,🎥 Netflix
  - DOMAIN-SUFFIX,nflxso.net,🎥 Netflix
  - DOMAIN-SUFFIX,nflxvideo.net,🎥 Netflix
  
  - DOMAIN-SUFFIX,disneyplus.com,🎬 Disney+
  - DOMAIN-SUFFIX,disney-plus.net,🎬 Disney+
  - DOMAIN-SUFFIX,disneystreaming.com,🎬 Disney+
  - DOMAIN-SUFFIX,dssott.com,🎬 Disney+
  
  - DOMAIN-SUFFIX,youtube.com,📹 YouTube
  - DOMAIN-SUFFIX,googlevideo.com,📹 YouTube
  - DOMAIN-SUFFIX,ytimg.com,📹 YouTube
  - DOMAIN-SUFFIX,youtu.be,📹 YouTube
  
  - DOMAIN-SUFFIX,spotify.com,🎵 Spotify
  - DOMAIN-SUFFIX,scdn.co,🎵 Spotify
  - DOMAIN-SUFFIX,spotilocal.com,🎵 Spotify
  
  # Telegram
  - RULE-SET,telegramcidr,📲 电报消息,no-resolve
  - DOMAIN-SUFFIX,t.me,📲 电报消息
  - DOMAIN-SUFFIX,tdesktop.com,📲 电报消息
  - DOMAIN-SUFFIX,telegra.ph,📲 电报消息
  - DOMAIN-SUFFIX,telegram.me,📲 电报消息
  - DOMAIN-SUFFIX,telegram.org,📲 电报消息
  
  # 游戏平台
  - DOMAIN-SUFFIX,steam.com,🎮 游戏平台
  - DOMAIN-SUFFIX,steampowered.com,🎮 游戏平台
  - DOMAIN-SUFFIX,steamcommunity.com,🎮 游戏平台
  - DOMAIN-SUFFIX,epicgames.com,🎮 游戏平台
  - DOMAIN-SUFFIX,battlenet.com,🎮 游戏平台
  
  # 苹果服务
  - RULE-SET,icloud,🍎 苹果服务
  - RULE-SET,apple,🍎 苹果服务
  
  # 微软服务
  - DOMAIN-SUFFIX,microsoft.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,windows.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,office.com,Ⓜ️ 微软服务
  - DOMAIN-SUFFIX,live.com,Ⓜ️ 微软服务
  
  # 国外服务
  - RULE-SET,google,🌍 国外流量
  - RULE-SET,proxy,🌍 国外流量
  - RULE-SET,gfw,🌍 国外流量
  
  # 国内服务
  - RULE-SET,direct,🎯 国内流量
  - RULE-SET,cncidr,🎯 国内流量,no-resolve
  - GEOIP,CN,🎯 国内流量,no-resolve
  
  # 兜底规则
  - MATCH,🐟 漏网之鱼
```

### 2. 应用配置

```bash
# SSH 连接到 mihomo VM (10.0.0.4)

# 备份原配置
sudo cp /etc/mihomo/config.yaml /etc/mihomo/config.yaml.backup

# 编辑配置（粘贴上面的完整配置）
sudo nano /etc/mihomo/config.yaml

# ⚠️ 重要：修改订阅地址
# 找到 proxy-providers -> my-subscription -> url
# 替换为你的实际订阅地址

# 检查配置语法
mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml

# 重启服务
sudo systemctl restart mihomo

# 查看状态
sudo systemctl status mihomo

# 查看日志
journalctl -u mihomo -f
```

---

## 二、AdGuard Home 完整配置

### 1. Web 界面初始化

浏览器访问：`http://10.0.0.5:3000`

1. **初始设置向导**
   - Web 界面端口：`80`（或保持 `3000`）
   - DNS 服务器端口：`53`
   - 设置管理员账号密码

2. **完成后登录**：`http://10.0.0.5`

### 2. DNS 设置

**设置 → 常规设置 → DNS 设置**

**上游 DNS 服务器：**
```
# 使用 mihomo 的 DNS（带分流）
127.0.0.1:1053

# 备用 DNS（mihomo 故障时自动切换）
https://doh.pub/dns-query
https://dns.alidns.com/dns-query
223.5.5.5
119.29.29.29
```

**Bootstrap DNS 服务器：**
```
223.5.5.5
119.29.29.29
```

**DNS 服务器配置：**
- ✅ 启用并行请求
- ✅ 启用 DNSSEC
- ✅ 启用 EDNS Client Subnet
- ❌ 禁用 IPv6（如果不需要）

**速率限制：**
- 限制每秒请求数：`30`

### 3. 过滤规则

**过滤器 → DNS 封锁清单**

点击"添加阻止列表" → "添加自定义列表"，逐个添加：

```
# Anti-AD（中文）
https://anti-ad.net/easylist.txt

# AdGuard DNS filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# EasyList China
https://easylist-downloads.adblockplus.org/easylistchina.txt

# 乘风视频过滤规则
https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/mv.txt

# CJX's Annoyance List
https://raw.githubusercontent.com/cjx82630/cjxlist/master/cjx-annoyance.txt
```

**DNS 白名单（允许清单）：**

```
# Anti-AD 白名单
https://raw.githubusercontent.com/privacy-protection-tools/dead-horse/master/anti-ad-white-list.txt
```

**应用规则：**
- 点击"保存"
- 点击"立即更新过滤器"

### 4. 查询日志设置

**设置 → 常规设置 → 日志配置**

- 保留时间：`24 小时`（节省空间）
- ✅ 启用查询日志
- ✅ 启用匿名化客户端 IP（隐私保护）

### 5. 自定义过滤规则

**过滤器 → 自定义过滤规则**

添加一些常用的手动规则：

```
# 拦截常见广告域名
||ad.*.com^
||ads.*.com^
||analytics.*.com^
||tracker.*.com^

# 拦截常见跟踪器
||google-analytics.com^
||googletagmanager.com^
||facebook.com/tr^

# 允许常用服务（避免误拦）
@@||github.com^
@@||jsdelivr.net^
@@||cloudflare.com^
```

### 6. 客户端设置（可选）

如果需要针对特定设备的规则：

**设置 → 客户端设置**

示例：
- 客户端名称：`小米电视`
- 标识符：`10.0.0.150`
- 阻止的服务：启用"广告和跟踪器"

---

## 三、RouterOS 完整配置（带容错）

### 核心思路：备用 DNS + 健康检查

当 AdGuard Home 或 mihomo 故障时，RouterOS 自动切换到备用 DNS（阿里 DNS、腾讯 DNS）。

### 1. 基础网络配置

```bash
# 设置主接口 IP
/ip address
add address=10.0.0.2/24 interface=ether1 comment="Main LAN"

# 设置网关
/ip route
add gateway=10.0.0.1 comment="Default Gateway"
```

### 2. DNS 配置（带容错）

```bash
# 设置 DNS 服务器（主+备）
/ip dns
set servers=10.0.0.5,223.5.5.5,119.29.29.29 \
    allow-remote-requests=yes \
    cache-size=10240 \
    cache-max-ttl=1d

# 解释：
# - 10.0.0.5 是 AdGuard Home（主DNS）
# - 223.5.5.5 是阿里DNS（备DNS 1）
# - 119.29.29.29 是腾讯DNS（备DNS 2）
# 当 AdGuard Home 故障时，自动使用备DNS
```

### 3. DHCP 配置（带容错）

```bash
# 创建 IP 池
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

# 配置 DHCP 服务器
/ip dhcp-server
add name=dhcp1 interface=ether1 address-pool=dhcp-pool disabled=no

# DHCP 网络配置（多个 DNS）
/ip dhcp-server network
add address=10.0.0.0/24 \
    gateway=10.0.0.2 \
    dns-server=10.0.0.5,223.5.5.5,119.29.29.29 \
    comment="DHCP with failover DNS"

# 解释：客户端会收到 3 个 DNS 地址
# 优先使用 AdGuard Home，故障时自动切换
```

### 4. DNS 劫持（可选但推荐）

```bash
# 强制所有 DNS 查询到 AdGuard Home
/ip firewall nat
add chain=dstnat action=dst-nat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 to-ports=53 \
    comment="DNS Hijack to AdGuard"

# 同样劫持 TCP DNS
add chain=dstnat action=dst-nat protocol=tcp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 to-ports=53 \
    comment="DNS Hijack TCP"

# ⚠️ 注意：如果 AdGuard Home 完全挂掉，需要手动禁用这条规则
```

### 5. 健康检查脚本（容错关键）

创建自动检查脚本，AdGuard Home 挂掉时自动禁用 DNS 劫持。

```bash
# 创建健康检查脚本
/system script
add name=check-adguard source={
    # 测试 AdGuard Home 是否在线
    :local adguardIP "10.0.0.5"
    :local testResult [/ping $adguardIP count=2]
    
    :if ($testResult = 0) do={
        # AdGuard Home 离线，禁用 DNS 劫持
        /ip firewall nat disable [find comment="DNS Hijack to AdGuard"]
        /log warning "AdGuard Home is DOWN! DNS hijack disabled."
    } else={
        # AdGuard Home 在线，启用 DNS 劫持
        /ip firewall nat enable [find comment="DNS Hijack to AdGuard"]
        /log info "AdGuard Home is UP! DNS hijack enabled."
    }
}

# 创建定时任务（每分钟检查一次）
/system scheduler
add name=check-adguard-schedule \
    on-event=check-adguard \
    interval=1m \
    comment="Check AdGuard Home health"
```

### 6. 防火墙规则（安全）

```bash
# ========== INPUT 链 ==========
/ip firewall filter

# 允许已建立的连接
add chain=input action=accept \
    connection-state=established,related \
    comment="Accept established"

# 允许 ICMP（ping）
add chain=input action=accept protocol=icmp \
    comment="Accept ICMP"

# 允许局域网访问路由器
add chain=input action=accept \
    src-address=10.0.0.0/24 \
    comment="Accept from LAN"

# 允许特定服务（SSH、Winbox）
add chain=input action=accept protocol=tcp dst-port=22 \
    src-address=10.0.0.0/24 comment="SSH from LAN"
add chain=input action=accept protocol=tcp dst-port=8291 \
    src-address=10.0.0.0/24 comment="Winbox from LAN"

# 拒绝其他入站
add chain=input action=drop comment="Drop all other input"

# ========== FORWARD 链 ==========
# FastTrack（硬件加速）
add chain=forward action=fasttrack-connection \
    connection-state=established,related \
    comment="FastTrack for performance"

# 允许已建立的连接
add chain=forward action=accept \
    connection-state=established,related \
    comment="Accept established"

# 允许新连接（出站）
add chain=forward action=accept \
    connection-state=new \
    connection-nat-state=!dstnat \
    comment="Accept new outbound"

# 拒绝无效连接
add chain=forward action=drop \
    connection-state=invalid \
    comment="Drop invalid"

# 拒绝其他转发
add chain=forward action=drop comment="Drop all other forward"
```

### 7. NAT 配置

```bash
# 源地址转换（Masquerade）
/ip firewall nat
add chain=srcnat action=masquerade \
    out-interface=ether1 \
    comment="Masquerade for internet"
```

### 8. 保护关键服务

```bash
# 防止外部访问 mihomo 和 AdGuard Home
/ip firewall filter
add chain=forward action=accept \
    src-address=10.0.0.0/24 \
    dst-address=10.0.0.4 \
    comment="Allow LAN to mihomo"

add chain=forward action=accept \
    src-address=10.0.0.0/24 \
    dst-address=10.0.0.5 \
    comment="Allow LAN to AdGuard"

add chain=forward action=drop \
    dst-address=10.0.0.4-10.0.0.5 \
    comment="Block external to services"
```

---

## 四、容错测试

### 测试 1：AdGuard Home 故障

```bash
# 在 AdGuard Home VM 上停止服务
sudo systemctl stop AdGuardHome

# 在客户端测试 DNS
nslookup baidu.com
# 应该依然能解析（使用备用DNS）

# 在 RouterOS 上查看日志
/log print where topics~"system"
# 应该看到 "AdGuard Home is DOWN!" 的警告

# 恢复服务
sudo systemctl start AdGuardHome
```

### 测试 2：mihomo 故障

```bash
# 在 mihomo VM 上停止服务
sudo systemctl stop mihomo

# AdGuard Home 会自动切换到备用 DNS（不经过 mihomo）
# 分流功能失效，但 DNS 解析和上网正常

# 恢复服务
sudo systemctl start mihomo
```

### 测试 3：完整故障

```bash
# 同时停止 mihomo 和 AdGuard Home
sudo systemctl stop mihomo       # 在 10.0.0.4 上
sudo systemctl stop AdGuardHome  # 在 10.0.0.5 上

# 客户端依然可以上网（使用备用 DNS）
# 但失去分流和广告过滤功能

# RouterOS 会自动禁用 DNS 劫持
# 所有流量直接使用备用 DNS
```

---

## 五、监控与维护

### 1. mihomo 监控

```bash
# 查看服务状态
systemctl status mihomo

# 实时日志
journalctl -u mihomo -f

# 测试代理
curl -x http://10.0.0.4:7890 google.com

# 查看 API（如果启用）
curl http://10.0.0.4:9090/
```

### 2. AdGuard Home 监控

Web 界面：`http://10.0.0.5`

- **仪表板**：查看拦截统计、查询量
- **查询日志**：查看 DNS 查询记录
- **过滤器**：查看规则更新状态

### 3. RouterOS 监控

```bash
# 查看 DNS 缓存
/ip dns cache print

# 查看活动连接
/ip firewall connection print count-only

# 查看日志
/log print

# 查看系统资源
/system resource print

# 测试 DNS 解析
/tool fetch url=http://google.com
```

---

## 六、故障处理流程

### 场景 1：无法上网

1. **检查 RouterOS**
   ```bash
   /ping 8.8.8.8
   # 能 ping 通 → RouterOS 正常
   # 不能 ping 通 → 检查网关和线路
   ```

2. **检查客户端 DNS**
   ```bash
   nslookup baidu.com
   # 能解析 → DNS 正常
   # 不能解析 → 检查 AdGuard Home
   ```

3. **检查 AdGuard Home**
   ```bash
   # SSH 到 10.0.0.5
   systemctl status AdGuardHome
   journalctl -u AdGuardHome -n 50
   ```

4. **临时禁用 DNS 劫持**
   ```bash
   # 在 RouterOS 上
   /ip firewall nat disable [find comment~"DNS"]
   ```

### 场景 2：广告拦截失效

1. **检查 AdGuard Home 规则**
   - Web 界面 → 过滤器 → 检查是否启用
   - 点击"更新过滤器"

2. **清除客户端 DNS 缓存**
   ```bash
   # Windows
   ipconfig /flushdns
   
   # macOS/Linux
   sudo dscacheutil -flushcache
   ```

3. **检查 DNS 查询日志**
   - AdGuard Home → 查询日志
   - 搜索广告域名，查看是否被拦截

### 场景 3：代理分流失效

1. **检查 mihomo 状态**
   ```bash
   systemctl status mihomo
   journalctl -u mihomo -n 50
   ```

2. **检查订阅更新**
   ```bash
   # 查看订阅文件
   ls -lh /etc/mihomo/providers/
   
   # 手动触发更新（通过 API）
   curl -X PUT http://10.0.0.4:9090/providers/proxies/my-subscription
   ```

3. **测试代理连通性**
   ```bash
   curl -x http://10.0.0.4:7890 http://www.gstatic.com/generate_204
   ```

---

## 七、优化建议

### 1. mihomo 性能优化

编辑 `/etc/mihomo/config.yaml`，添加：

```yaml
profile:
  store-selected: true     # 保存选择的节点
  store-fake-ip: true      # 持久化 fake-ip

experimental:
  ignore-resolve-fail: true  # 忽略 DNS 解析失败
  sniff-tls-sni: true       # TLS SNI 嗅探
```

### 2. AdGuard Home 性能优化

- 减少查询日志保留时间（24小时）
- 启用并行 DNS 查询
- 定期清理旧日志

### 3. RouterOS 性能优化

```bash
# 优化连接跟踪
/ip firewall connection tracking
set enabled=yes
set tcp-established-timeout=1d
set tcp-close-timeout=10s
set udp-timeout=10s

# 增大 DNS 缓存
/ip dns
set cache-size=10240
set cache-max-ttl=1d
```

---

## 八、完整配置备份

### mihomo 备份

```bash
# 备份配置和数据
sudo tar -czf /root/mihomo-backup-$(date +%Y%m%d).tar.gz \
    /etc/mihomo \
    /etc/systemd/system/mihomo.service

# 恢复
sudo tar -xzf /root/mihomo-backup-*.tar.gz -C /
sudo systemctl daemon-reload
sudo systemctl restart mihomo
```

### AdGuard Home 备份

Web 界面：**设置 → 常规设置 → 导出配置**

或命令行：

```bash
sudo systemctl stop AdGuardHome
sudo tar -czf /root/adguard-backup-$(date +%Y%m%d).tar.gz \
    /opt/AdGuardHome
sudo systemctl start AdGuardHome
```

### RouterOS 备份

```bash
# 导出配置
/export file=router-backup-$(date +%Y%m%d)

# 创建系统备份
/system backup save name=router-backup-$(date +%Y%m%d)

# 下载备份文件到本地
/tool fetch address=10.0.0.100 \
    src-path=router-backup-*.rsc \
    mode=ftp
```

---

## 完成！🎉

你现在拥有一套**完整的、带容错机制**的分流+去广告方案：

✅ **智能分流**：国内外自动分流，流媒体优化  
✅ **广告过滤**：全网广告拦截，多规则源  
✅ **容错机制**：任何服务故障都不影响上网  
✅ **自动恢复**：服务恢复后自动启用功能  
✅ **监控告警**：RouterOS 自动检测服务健康  

**关键点回顾：**
1. mihomo 提供智能分流
2. AdGuard Home 提供广告过滤
3. RouterOS 配置多个备用 DNS
4. 健康检查脚本自动容错
5. FastTrack 加速提升性能

如有问题，随时查看日志排查！

