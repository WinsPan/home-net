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

```
客户端 → RouterOS (10.0.0.2) → mihomo (10.0.0.4) → AdGuard Home (10.0.0.5) → 互联网
           ↓                         ↓                      ↓
       DNS劫持                   智能分流               广告过滤
```

**容错机制**：
- RouterOS 配置多 DNS（10.0.0.5, 223.5.5.5, 119.29.29.29）
- 任一服务故障，网络自动切换备用路径
- 保证上网不中断

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
  # 主力机场
  main-airport:
    type: http
    url: "https://your-subscription-url"     # ⚠️ 替换订阅地址
    interval: 3600                           # 1小时更新
    path: ./providers/main.yaml
    health-check:
      enable: true
      interval: 600
      lazy: true
      url: http://www.gstatic.com/generate_204
  
  # 备用机场（可选）
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

**1. 订阅地址**
```yaml
proxy-providers:
  main-airport:
    url: "你的机场订阅链接"  # ⚠️ 必须修改
```

**2. 策略选择**
- `💡 智能选择`：日常使用（自动选最快）
- `⚖️ 负载均衡`：下载任务（带宽叠加）
- `🔄 故障转移`：重要连接（高可用）

**3. 多机场**
取消注释 `backup-airport` 即可添加备用机场

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

```bash
# 测试代理连接
curl -x http://10.0.0.4:7890 https://www.google.com -I

# 测试 IP
curl -x http://10.0.0.4:7890 https://ip.sb
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

**Q: 如何切换策略？**

Web 管理：`http://10.0.0.4:9090`

命令行：
```bash
# 查看当前策略
curl http://10.0.0.4:9090/proxies

# 切换节点（通过 Web 界面更方便）
```

**Q: 广告没拦截？**

1. 检查 AdGuard Home 规则是否启用
2. 清除浏览器和 DNS 缓存
3. 查看 AdGuard Home 查询日志

**Q: 无法访问某些网站？**

1. 检查 mihomo 日志
2. 验证订阅是否更新
3. 尝试切换节点

**Q: 服务故障怎么办？**

RouterOS 已配置备用 DNS，服务故障时：
- 网络自动切换备用路径
- 功能失效但上网不中断
- 修复服务后自动恢复功能

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

