# mihomo + AdGuard Home 完整配置指南

智能分流 + 广告过滤 + 容错机制的完整解决方案

---

## 📋 目录

- [网络架构](#网络架构)
- [mihomo 配置](#mihomo-配置)
- [AdGuard Home 配置](#adguardhome-配置)
- [RouterOS 配置](#routeros-配置)
- [验证测试](#验证测试)

---

## 网络架构

### 流量路径

```
客户端 → RouterOS (10.0.0.2) → mihomo (10.0.0.4) → AdGuard Home (10.0.0.5) → 互联网
           ↓                         ↓                      ↓
       DNS劫持                   智能分流               广告过滤
```

**容错机制**：
- RouterOS 配置多 DNS（10.0.0.5, 223.5.5.5, 119.29.29.29）
- 任一服务故障，网络自动切换备用路径
- 保证上网不中断

### 代理方式选择

有两种方式让流量经过 mihomo：

**方案一：设备手动设置代理（推荐）** ✅
- 优点：配置简单，稳定可靠
- 缺点：需要每个设备手动配置
- 适用：PC、手机等支持代理设置的设备

**方案二：透明代理（高级）** 🔧
- 优点：全局生效，无需设备配置
- 缺点：配置复杂，需要 RouterOS 策略路由
- 适用：需要全网代理的场景

> 💡 **建议**：新手使用方案一，高级用户可尝试方案二

---

## mihomo 配置

### 完整配置文件 `/etc/mihomo/config.yaml`

```yaml
# ==================== 基础配置 ====================
port: 7890
socks-port: 7891
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
ipv6: false
external-controller: 0.0.0.0:9090
secret: ""                      # ⚠️ 建议设置 API 密钥

# 配置持久化
profile:
  store-selected: true
  store-fake-ip: true

# ==================== DNS 配置 ====================
dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "localhost.ptlogin2.qq.com"
  
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  
  fallback:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
  
  fallback-filter:
    geoip: true
    geoip-code: CN

# ==================== 机场订阅 ====================
proxy-providers:
  # ========== 方式一：直接订阅（推荐）==========
  
  # 主力机场
  main-airport:
    type: http
    url: "https://your-subscription-url"     # ⚠️ 替换为你的订阅地址
    interval: 3600                           # 1小时更新一次
    path: ./providers/main.yaml
    health-check:
      enable: true
      interval: 600                          # 10分钟检查一次
      lazy: true                             # 懒加载（使用时才检查）
      url: http://www.gstatic.com/generate_204
      # url: http://cp.cloudflare.com/generate_204  # 备用测试地址
  
  # 备用机场（多机场负载/故障转移）
  # backup-airport:
  #   type: http
  #   url: "https://your-backup-subscription"
  #   interval: 3600
  #   path: ./providers/backup.yaml
  #   health-check:
  #     enable: true
  #     interval: 600
  #     lazy: true
  #     url: http://www.gstatic.com/generate_204
  
  # ========== 方式二：订阅转换（高级）==========
  # 如果机场订阅不兼容 mihomo，使用订阅转换
  
  # 使用订阅转换 API
  # converted-subscription:
  #   type: http
  #   # 常用订阅转换服务：
  #   # - https://sub.xeton.dev/sub
  #   # - https://api.dler.io/sub
  #   # - https://sub-web.netlify.app/api/v1/sub
  #   url: "https://sub.xeton.dev/sub?target=clash&url=你的订阅地址&insert=false&config=你的远程配置"
  #   interval: 3600
  #   path: ./providers/converted.yaml
  #   health-check:
  #     enable: true
  #     interval: 600
  #     lazy: true
  #     url: http://www.gstatic.com/generate_204
  
  # ========== 方式三：本地节点（测试用）==========
  # 本地配置的固定节点
  # local-nodes:
  #   type: file
  #   path: ./providers/local-nodes.yaml
  #   health-check:
  #     enable: true
  #     interval: 300
  #     lazy: false

# ==================== 策略组 ====================
proxy-groups:
  # 主选择器
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "💡 智能选择"
      - "⚖️ 负载均衡"
      - "🔄 故障转移"
      - "🇭🇰 香港"
      - "🇸🇬 新加坡"
      - "🇯🇵 日本"
      - "🇺🇸 美国"
      - DIRECT
  
  # 智能选择 - 自动选最快
  - name: "💡 智能选择"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: false
    url: http://www.gstatic.com/generate_204
    use:
      - main-airport
      # - backup-airport
  
  # 负载均衡 - 带宽叠加
  - name: "⚖️ 负载均衡"
    type: load-balance
    strategy: consistent-hashing
    url: http://www.gstatic.com/generate_204
    interval: 300
    use:
      - main-airport
  
  # 故障转移 - 高可用
  - name: "🔄 故障转移"
    type: fallback
    url: http://www.gstatic.com/generate_204
    interval: 300
    use:
      - main-airport
  
  # 地区节点
  - name: "🇭🇰 香港"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main-airport]
    filter: "(?i)港|hk|hongkong"
  
  - name: "🇸🇬 新加坡"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main-airport]
    filter: "(?i)新|坡|狮|sg|singapore"
  
  - name: "🇯🇵 日本"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main-airport]
    filter: "(?i)日|jp|japan"
  
  - name: "🇺🇸 美国"
    type: url-test
    tolerance: 50
    interval: 300
    lazy: true
    use: [main-airport]
    filter: "(?i)美|us|america|united"
  
  # 应用分组
  - name: "📹 YouTube"
    type: select
    proxies: ["💡 智能选择", "🇭🇰 香港", "🇸🇬 新加坡", "🚀 节点选择"]
  
  - name: "🎥 Netflix"
    type: select
    proxies: ["💡 智能选择", "🇭🇰 香港", "🇸🇬 新加坡", "🇯🇵 日本", "🇺🇸 美国"]
  
  - name: "📲 Telegram"
    type: select
    proxies: ["💡 智能选择", "🇭🇰 香港", "🇸🇬 新加坡"]
  
  - name: "🍎 苹果"
    type: select
    proxies: ["DIRECT", "💡 智能选择", "🇺🇸 美国"]
  
  - name: "🌍 国外"
    type: select
    proxies: ["💡 智能选择", "⚖️ 负载均衡", "🔄 故障转移", "DIRECT"]
  
  - name: "🎯 国内"
    type: select
    proxies: ["DIRECT", "💡 智能选择"]
  
  - name: "🛡️ 拦截"
    type: select
    proxies: ["REJECT", "DIRECT"]
  
  - name: "🐟 漏网"
    type: select
    proxies: ["💡 智能选择", "DIRECT"]

# ==================== 规则集 ====================
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
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
  
  gfw:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400
  
  apple:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt"
    path: ./ruleset/apple.yaml
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
  # 局域网
  - RULE-SET,lancidr,DIRECT
  
  # 广告拦截
  - RULE-SET,reject,🛡️ 拦截
  
  # Telegram
  - RULE-SET,telegramcidr,📲 Telegram,no-resolve
  - DOMAIN-SUFFIX,t.me,📲 Telegram
  - DOMAIN-SUFFIX,telegram.org,📲 Telegram
  
  # YouTube
  - DOMAIN-SUFFIX,youtube.com,📹 YouTube
  - DOMAIN-SUFFIX,googlevideo.com,📹 YouTube
  - DOMAIN-SUFFIX,ytimg.com,📹 YouTube
  
  # Netflix
  - DOMAIN-SUFFIX,netflix.com,🎥 Netflix
  - DOMAIN-SUFFIX,netflix.net,🎥 Netflix
  - DOMAIN-KEYWORD,netflix,🎥 Netflix
  
  # 苹果
  - RULE-SET,apple,🍎 苹果
  
  # 国外
  - RULE-SET,proxy,🌍 国外
  - RULE-SET,gfw,🌍 国外
  
  # 国内
  - RULE-SET,direct,🎯 国内
  - RULE-SET,cncidr,🎯 国内,no-resolve
  - GEOIP,CN,🎯 国内
  
  # 兜底
  - MATCH,🐟 漏网
```

### 配置要点

#### 1. 订阅地址配置

**获取订阅地址：**
1. 从你的机场获取 Clash/mihomo 订阅链接
2. 通常格式：`https://机场域名/api/v1/client/subscribe?token=xxx`

**直接使用（推荐）：**
```yaml
proxy-providers:
  main-airport:
    url: "https://your-airport.com/api/v1/client/subscribe?token=xxx"
```

**订阅转换（不兼容时使用）：**

如果机场订阅不支持 mihomo/Clash，使用订阅转换：

```yaml
proxy-providers:
  converted:
    url: "https://sub.xeton.dev/sub?target=clash&url=你的原始订阅&insert=false"
```

**常用转换服务：**
- `https://sub.xeton.dev/sub` - 稳定可靠
- `https://api.dler.io/sub` - 功能丰富
- `https://sub.id/sub` - 国内访问快

**转换参数说明：**
```
target=clash        # 目标格式（clash/mihomo 通用）
url=订阅地址        # URL 编码后的订阅地址
insert=false        # 不插入默认节点
config=配置地址     # 远程配置（可选）
emoji=true          # 显示 emoji（可选）
```

#### 2. 多机场配置

**场景一：主备切换**
```yaml
proxy-providers:
  main:
    url: "机场1订阅"
  backup:
    url: "机场2订阅"

proxy-groups:
  - name: "🔄 故障转移"
    type: fallback
    use: [main, backup]
```

**场景二：负载均衡**
```yaml
proxy-groups:
  - name: "⚖️ 负载均衡"
    type: load-balance
    strategy: consistent-hashing
    use: [main, backup]
```

**场景三：手动选择**
```yaml
proxy-groups:
  - name: "🌐 全部节点"
    type: select
    use:
      - main
      - backup
      - special  # 流媒体专用机场
```

#### 3. 节点过滤与筛选

**按地区筛选：**
```yaml
proxy-groups:
  - name: "🇭🇰 香港节点"
    type: url-test
    use: [main, backup]
    filter: "(?i)港|hk|hongkong|hong kong"
    
  - name: "🇺🇸 美国节点"
    filter: "(?i)美|us|america|united states"
```

**排除节点：**
```yaml
# 排除过期或测试节点
filter: "^(?!.*(过期|到期|剩余|官网|测试)).*$"

# 只保留高级节点
filter: "(?i)(premium|pro|plus|vip)"

# 排除特定地区
filter: "^(?!.*(印度|俄罗斯)).*$"
```

#### 4. 策略选择

- `💡 智能选择` (`url-test`)：自动选最快，日常推荐
- `⚖️ 负载均衡` (`load-balance`)：下载任务，带宽叠加
- `🔄 故障转移` (`fallback`)：高可用，自动切换
- `🌐 手动选择` (`select`)：完全自定义

#### 5. 健康检查优化

```yaml
health-check:
  enable: true
  interval: 600          # 检查间隔（秒）
  lazy: true            # 懒加载（节省资源）
  url: http://www.gstatic.com/generate_204
  # 备用测试地址：
  # - http://cp.cloudflare.com/generate_204
  # - http://www.apple.com/library/test/success.html
  # - https://www.google.com/generate_204
```

**性能建议：**
- 日常使用：`lazy: true` + `interval: 600`（10分钟）
- 重要业务：`lazy: false` + `interval: 300`（5分钟）
- 节省资源：`lazy: true` + `interval: 1800`（30分钟）

---

## AdGuard Home 配置

### 1. 初始化

访问：`http://10.0.0.5:3000`

设置：
- Web 端口：`80`
- DNS 端口：`53`
- 管理员账号密码

### 2. DNS 设置

**上游 DNS**（设置 → DNS 设置 → 上游 DNS 服务器）：
```
127.0.0.1:1053
https://doh.pub/dns-query
https://dns.alidns.com/dns-query
223.5.5.5
119.29.29.29
```

**Bootstrap DNS**：
```
223.5.5.5
119.29.29.29
```

**选项**：
- ✅ 启用并行请求
- ✅ 启用 DNSSEC
- ✅ EDNS Client Subnet

### 3. 过滤规则

**DNS 封锁清单**（过滤器 → DNS 封锁清单 → 添加阻止列表）：

```
# Anti-AD
https://anti-ad.net/easylist.txt

# AdGuard Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# EasyList China
https://easylist-downloads.adblockplus.org/easylistchina.txt

# CJX Annoyance
https://raw.githubusercontent.com/cjx82630/cjxlist/master/cjx-annoyance.txt
```

**DNS 允许清单**：
```
# Anti-AD 白名单
https://raw.githubusercontent.com/privacy-protection-tools/dead-horse/master/anti-ad-white-list.txt
```

### 4. 优化设置

**查询日志**（设置 → 常规设置 → 日志配置）：
- 保留时间：`24 小时`
- ✅ 启用匿名化客户端 IP

**速率限制**：
- 限制每秒请求数：`30`

---

## RouterOS 配置

### 重要说明

RouterOS 主要负责：
1. **DNS 劫持** - 所有 DNS 查询到 AdGuard Home
2. **DHCP 分发** - 自动分配 IP 和 DNS
3. **代理路由**（可选）- 透明代理流量到 mihomo

### 1. DNS 配置（带容错）

```bash
# 设置多 DNS（主 + 备）
/ip dns
set servers=10.0.0.5,223.5.5.5,119.29.29.29
set allow-remote-requests=yes
set cache-size=10240
set cache-max-ttl=1d
```

### 2. DHCP 配置

```bash
# 创建 IP 池
/ip pool
add name=dhcp-pool ranges=10.0.0.100-10.0.0.200

# DHCP 服务器
/ip dhcp-server
add name=dhcp1 interface=ether1 address-pool=dhcp-pool

# DHCP 网络（多 DNS）
/ip dhcp-server network
add address=10.0.0.0/24 \
    gateway=10.0.0.2 \
    dns-server=10.0.0.5,223.5.5.5,119.29.29.29
```

### 3. DNS 劫持（可选）

```bash
# 强制所有 DNS 到 AdGuard Home
/ip firewall nat
add chain=dstnat protocol=udp dst-port=53 \
    dst-address=!10.0.0.5 \
    to-addresses=10.0.0.5 \
    comment="DNS Hijack"
```

### 4. 健康检查脚本（容错关键）

```bash
# 创建健康检查
/system script
add name=check-adguard source={
    :local adguardIP "10.0.0.5"
    :local testResult [/ping $adguardIP count=2]
    
    :if ($testResult = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
        /log warning "AdGuard DOWN! DNS hijack disabled."
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}

# 定时任务（每分钟）
/system scheduler
add name=check-adguard-schedule \
    on-event=check-adguard \
    interval=1m
```

### 5. 防火墙（安全）

```bash
/ip firewall filter
# 允许已建立连接
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=10.0.0.0/24
add chain=input action=accept protocol=icmp
add chain=input action=drop

# FastTrack 加速
add chain=forward action=fasttrack-connection \
    connection-state=established,related
add chain=forward action=accept connection-state=established,related
```

### 6. 代理配置

#### 方案一：设备手动设置代理（推荐）✅

**无需 RouterOS 额外配置**，只需在客户端设备设置：

**Windows:**
```
设置 → 网络和Internet → 代理
- HTTP 代理: 10.0.0.4
- 端口: 7890
```

**macOS:**
```
系统偏好设置 → 网络 → 高级 → 代理
- HTTP 代理: 10.0.0.4:7890
- HTTPS 代理: 10.0.0.4:7890
- SOCKS 代理: 10.0.0.4:7891
```

**iOS/Android:**
```
WiFi 设置 → 配置代理 → 手动
- 服务器: 10.0.0.4
- 端口: 7890
```

**浏览器扩展（推荐）:**
- SwitchyOmega (Chrome/Edge)
- Proxy SwitchyOmega (Firefox)

配置示例：
```
代理协议: HTTP
代理服务器: 10.0.0.4
代理端口: 7890
```

#### 方案二：透明代理（高级）🔧

**需要额外配置 RouterOS 和 mihomo**

##### A. mihomo 透明代理配置

编辑 `/etc/mihomo/config.yaml`，添加：

```yaml
# 在基础配置部分添加
tproxy-port: 7893
```

在 mihomo VM 上创建 iptables 规则脚本：

```bash
sudo nano /opt/mihomo/tproxy-setup.sh
```

```bash
#!/bin/bash

# 清理旧规则
iptables -t mangle -F
iptables -t nat -F

# 创建 CLASH 链
iptables -t mangle -N CLASH

# 忽略本地和保留地址
iptables -t mangle -A CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A CLASH -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A CLASH -d 240.0.0.0/4 -j RETURN

# 重定向到 mihomo
iptables -t mangle -A CLASH -p tcp -j TPROXY --on-port 7893 --tproxy-mark 1
iptables -t mangle -A CLASH -p udp -j TPROXY --on-port 7893 --tproxy-mark 1

# 应用到 PREROUTING
iptables -t mangle -A PREROUTING -j CLASH

# 配置路由
ip rule add fwmark 1 table 100
ip route add local 0.0.0.0/0 dev lo table 100

echo "TProxy 规则已配置"
```

```bash
sudo chmod +x /opt/mihomo/tproxy-setup.sh
sudo /opt/mihomo/tproxy-setup.sh
```

**开机自动加载：**

```bash
sudo nano /etc/systemd/system/mihomo-tproxy.service
```

```ini
[Unit]
Description=mihomo TProxy Rules
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/mihomo/tproxy-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable mihomo-tproxy
sudo systemctl start mihomo-tproxy
```

##### B. RouterOS 透明代理配置

```bash
# 标记需要代理的流量
/ip firewall mangle
add chain=prerouting \
    src-address=10.0.0.0/24 \
    dst-address-list=!local \
    action=mark-routing \
    new-routing-mark=proxy_route \
    passthrough=yes \
    comment="Mark proxy traffic"

# 排除本地流量
/ip firewall address-list
add list=local address=10.0.0.0/24
add list=local address=192.168.0.0/16
add list=local address=172.16.0.0/12

# 路由标记的流量到 mihomo
/ip route
add dst-address=0.0.0.0/0 \
    gateway=10.0.0.4 \
    routing-mark=proxy_route \
    comment="Route to mihomo"

# NAT 转发到 mihomo TProxy 端口
/ip firewall nat
add chain=dstnat \
    src-address=10.0.0.0/24 \
    dst-address-list=!local \
    protocol=tcp \
    action=dst-nat \
    to-addresses=10.0.0.4 \
    to-ports=7893 \
    comment="Redirect to mihomo TProxy"
```

**注意事项：**
- 透明代理会影响所有设备
- 需要确保 mihomo 稳定运行
- 可能导致某些应用无法使用
- 建议先用方案一测试

---

## 验证测试

### 1. DNS 测试

```bash
# 测试 DNS 解析
nslookup google.com 10.0.0.5
nslookup baidu.com 10.0.0.5

# 测试广告拦截
curl -I http://ad.doubleclick.net
# 应返回被拦截
```

### 2. 代理测试

#### 方案一测试（手动代理）

```bash
# 测试 HTTP 代理
curl -x http://10.0.0.4:7890 https://www.google.com -I

# 测试 SOCKS5 代理
curl --socks5 10.0.0.4:7891 https://www.google.com -I

# 查看代理后的 IP
curl -x http://10.0.0.4:7890 https://ip.sb
curl -x http://10.0.0.4:7890 https://myip.ipip.net
```

#### 方案二测试（透明代理）

```bash
# 在客户端测试（无需设置代理）
curl https://www.google.com -I

# 查看 IP（应显示代理节点 IP）
curl https://ip.sb

# 在 mihomo VM 查看 iptables
sudo iptables -t mangle -L -n -v

# 查看路由表
ip rule show
ip route show table 100
```

### 3. 容错测试

```bash
# 停止 AdGuard Home
sudo systemctl stop AdGuardHome

# 客户端测试（应仍能上网）
ping baidu.com

# 恢复服务
sudo systemctl start AdGuardHome
```

### 4. 服务状态

```bash
# mihomo
systemctl status mihomo
journalctl -u mihomo -n 50

# AdGuard Home
systemctl status AdGuardHome
journalctl -u AdGuardHome -n 50

# RouterOS
/log print where topics~"dns"
```

---

## 常见问题

### 订阅相关

**Q: 订阅地址填写后无法更新？**

A: 检查以下几点：
```bash
# 1. 测试订阅地址是否可访问
curl -I "你的订阅地址"

# 2. 查看 mihomo 日志
journalctl -u mihomo -n 50 | grep -i "provider"

# 3. 手动触发更新（通过 API）
curl -X PUT http://10.0.0.4:9090/providers/proxies/main-airport

# 4. 检查订阅文件是否生成
ls -lh /etc/mihomo/providers/
```

**Q: 订阅转换怎么用？**

A: 使用订阅转换服务：
```yaml
# 方式一：使用公共转换服务
url: "https://sub.xeton.dev/sub?target=clash&url=你的订阅地址&insert=false"

# 方式二：URL 编码后
# 1. 访问 https://www.urlencoder.org/
# 2. 编码你的订阅地址
# 3. 替换 url= 后面的内容
url: "https://sub.xeton.dev/sub?target=clash&url=编码后的地址"
```

**常用转换服务对比：**
| 服务 | 速度 | 稳定性 | 功能 |
|------|------|--------|------|
| sub.xeton.dev | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 基础 |
| api.dler.io | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 丰富 |
| sub.id | ⭐⭐⭐ | ⭐⭐⭐ | 基础 |

**Q: 多个机场怎么配置？**

A: 三种常见配置：
```yaml
# 1. 故障转移（主备）
proxy-groups:
  - name: "🔄 转移"
    type: fallback
    use: [airport1, airport2]

# 2. 负载均衡（同时使用）
proxy-groups:
  - name: "⚖️ 负载"
    type: load-balance
    use: [airport1, airport2]

# 3. 手动选择（灵活切换）
proxy-groups:
  - name: "🌐 所有"
    type: select
    use: [airport1, airport2]
```

**Q: 节点筛选规则怎么写？**

A: 使用正则表达式：
```yaml
# 只要香港节点
filter: "(?i)港|hk|hongkong"

# 排除过期节点
filter: "^(?!.*(过期|到期|剩余)).*$"

# 只要 IPLC 线路
filter: "(?i)iplc"

# 排除高倍率节点
filter: "^(?!.*(x2|x3|x5)).*$"

# 组合条件：香港且非高倍率
filter: "(?=.*(港|hk))(?!.*(x2|x3)).*"
```

### 代理相关

**Q: 如何切换策略？**

Web 管理：`http://10.0.0.4:9090`

命令行：
```bash
# 查看当前策略
curl http://10.0.0.4:9090/proxies

# 切换节点（通过 Web 界面更方便）
```

**Q: 代理不生效？**

1. 检查设备代理设置是否正确
2. 测试代理连接：
```bash
curl -x http://10.0.0.4:7890 https://www.google.com -I
```
3. 查看 mihomo 日志：
```bash
journalctl -u mihomo -f
```
4. 检查节点是否可用：
   - 访问 Web 界面查看节点延迟
   - 手动切换其他节点测试

**Q: 部分网站无法访问？**

A: 可能的原因和解决方法：
1. **节点被墙** - 切换其他节点
2. **规则问题** - 检查是否被错误分流到直连
3. **DNS 污染** - 确认 DNS 走的是 AdGuard Home
4. **网站限制** - 某些网站屏蔽代理 IP

```bash
# 测试 DNS
nslookup 网站域名 10.0.0.5

# 查看规则匹配
journalctl -u mihomo -n 50 | grep "网站域名"

# 临时指定代理组测试
# 在 Web 界面手动选择不同策略组
```

### AdGuard Home 相关

**Q: 广告没拦截？**

1. 检查 AdGuard Home 规则是否启用
2. 清除浏览器和 DNS 缓存
3. 查看 AdGuard Home 查询日志
4. 确认设备 DNS 设置正确

**Q: 误拦截了正常网站？**

1. 查看 AdGuard Home 查询日志
2. 找到被拦截的域名
3. 添加到白名单或禁用对应规则

### 系统相关

**Q: 服务故障怎么办？**

RouterOS 已配置备用 DNS，服务故障时：
- 网络自动切换备用路径
- 功能失效但上网不中断
- 修复服务后自动恢复功能

**Q: 如何更新订阅？**

```bash
# 方式一：自动更新（已配置 interval: 3600）
# 每小时自动更新，无需手动操作

# 方式二：手动更新
curl -X PUT http://10.0.0.4:9090/providers/proxies/main-airport

# 方式三：重启服务（强制更新）
sudo systemctl restart mihomo
```

**Q: 性能优化建议？**

```yaml
# 1. 调整健康检查
health-check:
  lazy: true          # 启用懒加载
  interval: 600       # 降低检查频率

# 2. 启用持久化
profile:
  store-selected: true
  store-fake-ip: true

# 3. 合理使用策略
# - 日常：💡 智能选择
# - 下载：⚖️ 负载均衡
# - 稳定：🔄 故障转移
```

---

## 维护管理

### 更新 mihomo

```bash
/opt/mihomo/update-mihomo.sh
```

### 更新 AdGuard Home

Web 界面：设置 → 常规设置 → 检查更新

### 备份配置

```bash
# mihomo
sudo tar -czf ~/mihomo-backup.tar.gz /etc/mihomo

# AdGuard Home
sudo tar -czf ~/adguard-backup.tar.gz /opt/AdGuardHome

# RouterOS
/export file=router-backup
/system backup save name=router-backup
```

---

## 性能优化

**mihomo**：
```yaml
# 在 config.yaml 中
profile:
  store-selected: true
  store-fake-ip: true
```

**AdGuard Home**：
- 减少日志保留时间
- 启用并行查询
- 使用 DoH/DoT

**RouterOS**：
```bash
# 连接跟踪优化
/ip firewall connection tracking
set tcp-established-timeout=1d
set udp-timeout=10s

# DNS 缓存
/ip dns set cache-size=10240
```

---

## 完成！

你现在拥有：

✅ **智能分流** - 自动选择最优路径  
✅ **广告过滤** - 全网拦截  
✅ **容错机制** - 故障不断网  
✅ **自动更新** - 规则动态维护  
✅ **Web 管理** - 可视化控制  

如有问题，查看日志或提交 Issue！

