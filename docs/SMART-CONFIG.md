# mihomo 智能配置 - Smart 策略 + 多机场 + 动态规则

高级配置：智能选择、负载均衡、故障转移、动态规则更新

---

## 配置文件：`/etc/mihomo/config.yaml`

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
secret: "your-secret-here"  # ⚠️ 建议设置 API 密钥

# 自动更新配置
profile:
  store-selected: true        # 记住选择的节点
  store-fake-ip: true         # 持久化 fake-ip

# 实验性功能
experimental:
  ignore-resolve-fail: true   # 忽略 DNS 解析失败
  sniff-tls-sni: true         # TLS SNI 嗅探

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
    - "*.localdomain"
    - "localhost.ptlogin2.qq.com"
    - "time.*.com"
    - "ntp.*.com"
  
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

# ==================== 多机场订阅 ====================
proxy-providers:
  # 机场 1 - 主力机场
  airport-1:
    type: http
    url: "https://your-airport-1-subscription-url"  # ⚠️ 替换为实际订阅
    interval: 3600              # 1小时更新一次
    path: ./providers/airport-1.yaml
    health-check:
      enable: true
      interval: 600             # 10分钟检查一次
      lazy: true
      url: http://www.gstatic.com/generate_204
  
  # 机场 2 - 备用机场
  airport-2:
    type: http
    url: "https://your-airport-2-subscription-url"  # ⚠️ 替换为实际订阅
    interval: 3600
    path: ./providers/airport-2.yaml
    health-check:
      enable: true
      interval: 600
      lazy: true
      url: http://www.gstatic.com/generate_204
  
  # 机场 3 - 专用机场（流媒体/游戏等）
  airport-3:
    type: http
    url: "https://your-airport-3-subscription-url"  # ⚠️ 替换为实际订阅
    interval: 3600
    path: ./providers/airport-3.yaml
    health-check:
      enable: true
      interval: 600
      lazy: true
      url: http://www.gstatic.com/generate_204

# ==================== Smart 策略组 ====================
proxy-groups:
  # ========== 主策略组 ==========
  
  # 节点选择 - 手动选择
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "💡 智能选择"
      - "⚖️ 负载均衡"
      - "🔄 故障转移"
      - "♻️ 自动选择"
      - "🇭🇰 香港节点"
      - "🇨🇳 台湾节点"
      - "🇸🇬 狮城节点"
      - "🇯🇵 日本节点"
      - "🇺🇸 美国节点"
      - "🇰🇷 韩国节点"
      - "🌐 全部节点"
      - DIRECT
  
  # 💡 智能选择 - Smart 策略（推荐）
  # 结合延迟测试和负载均衡，自动选择最优节点
  - name: "💡 智能选择"
    type: url-test
    tolerance: 50               # 延迟容差（ms）
    interval: 300               # 5分钟测试一次
    lazy: false                 # 启动时立即测试
    url: http://www.gstatic.com/generate_204
    use:
      - airport-1
      - airport-2
      - airport-3
  
  # ⚖️ 负载均衡 - Load Balance
  # 在多个节点间分配流量，提高总带宽
  - name: "⚖️ 负载均衡"
    type: load-balance
    strategy: consistent-hashing  # 一致性哈希（同域名使用同节点）
    # strategy: round-robin       # 轮询
    url: http://www.gstatic.com/generate_204
    interval: 300
    use:
      - airport-1
      - airport-2
  
  # 🔄 故障转移 - Fallback
  # 主节点故障时自动切换到备用节点
  - name: "🔄 故障转移"
    type: fallback
    url: http://www.gstatic.com/generate_204
    interval: 300
    use:
      - airport-1               # 优先级最高
      - airport-2               # 备用
      - airport-3               # 最后备用
  
  # ♻️ 自动选择 - 延迟最低
  - name: "♻️ 自动选择"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - airport-1
      - airport-2
      - airport-3
  
  # ========== 地区分组（智能选择） ==========
  
  # 🇭🇰 香港节点
  - name: "🇭🇰 香港节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)港|hk|hongkong|hong kong"
  
  # 🇨🇳 台湾节点
  - name: "🇨🇳 台湾节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)台|tw|taiwan"
  
  # 🇸🇬 狮城节点
  - name: "🇸🇬 狮城节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)新加坡|坡|狮城|sg|singapore"
  
  # 🇯🇵 日本节点
  - name: "🇯🇵 日本节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)日本|jp|japan"
  
  # 🇺🇸 美国节点
  - name: "🇺🇸 美国节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)美|us|unitedstates|united states"
  
  # 🇰🇷 韩国节点
  - name: "🇰🇷 韩国节点"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - airport-1
      - airport-2
      - airport-3
    filter: "(?i)韩|kr|korea"
  
  # 🌐 全部节点 - 手动选择
  - name: "🌐 全部节点"
    type: select
    use:
      - airport-1
      - airport-2
      - airport-3
  
  # ========== 功能分组（智能策略） ==========
  
  # 📲 电报消息
  - name: "📲 电报消息"
    type: select
    proxies:
      - "💡 智能选择"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
      - "⚖️ 负载均衡"
      - DIRECT
  
  # 🎥 Netflix
  - name: "🎥 Netflix"
    type: select
    proxies:
      - "💡 智能选择"
      - "🇭🇰 香港节点"
      - "🇨🇳 台湾节点"
      - "🇸🇬 狮城节点"
      - "🇯🇵 日本节点"
      - "🇺🇸 美国节点"
  
  # 🎬 Disney+
  - name: "🎬 Disney+"
    type: select
    proxies:
      - "💡 智能选择"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
      - "🇺🇸 美国节点"
  
  # 📹 YouTube
  - name: "📹 YouTube"
    type: select
    proxies:
      - "💡 智能选择"
      - "⚖️ 负载均衡"
      - "🇭🇰 香港节点"
      - "🇸🇬 狮城节点"
  
  # 🎵 Spotify
  - name: "🎵 Spotify"
    type: select
    proxies:
      - "💡 智能选择"
      - DIRECT
  
  # 🎮 游戏平台
  - name: "🎮 游戏平台"
    type: select
    proxies:
      - DIRECT
      - "💡 智能选择"
      - "🇭🇰 香港节点"
      - "🇯🇵 日本节点"
  
  # 🍎 苹果服务
  - name: "🍎 苹果服务"
    type: select
    proxies:
      - DIRECT
      - "💡 智能选择"
      - "🇺🇸 美国节点"
  
  # Ⓜ️ 微软服务
  - name: "Ⓜ️ 微软服务"
    type: select
    proxies:
      - DIRECT
      - "💡 智能选择"
  
  # 🌍 国外流量
  - name: "🌍 国外流量"
    type: select
    proxies:
      - "💡 智能选择"
      - "⚖️ 负载均衡"
      - "🔄 故障转移"
      - "♻️ 自动选择"
      - DIRECT
  
  # 🎯 国内流量
  - name: "🎯 国内流量"
    type: select
    proxies:
      - DIRECT
      - "💡 智能选择"
  
  # 🛡️ 广告拦截
  - name: "🛡️ 广告拦截"
    type: select
    proxies:
      - REJECT
      - DIRECT
  
  # 🐟 漏网之鱼
  - name: "🐟 漏网之鱼"
    type: select
    proxies:
      - "💡 智能选择"
      - "🔄 故障转移"
      - DIRECT

# ==================== 动态规则集 ====================
rule-providers:
  # 广告拦截
  reject:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400           # 24小时更新
  
  # iCloud
  icloud:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400
  
  # Apple
  apple:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400
  
  # Google
  google:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400
  
  # 代理域名
  proxy:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400
  
  # 直连域名
  direct:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400
  
  # 私有网络
  private:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400
  
  # GFW 列表
  gfw:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400
  
  # Telegram IP 段
  telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400
  
  # 中国 IP 段
  cncidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400
  
  # 局域网 IP 段
  lancidr:
    type: http
    behavior: ipcidr
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400
  
  # OpenAI
  openai:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/openai.txt"
    path: ./ruleset/openai.yaml
    interval: 86400
  
  # Microsoft
  microsoft:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/ACL4SSR/ACL4SSR@master/Clash/Microsoft.list"
    path: ./ruleset/microsoft.yaml
    interval: 86400
  
  # 游戏平台
  games:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/ACL4SSR/ACL4SSR@master/Clash/Ruleset/Epic.list"
    path: ./ruleset/games.yaml
    interval: 86400

# ==================== 规则 ====================
rules:
  # 局域网直连
  - RULE-SET,private,DIRECT
  - RULE-SET,lancidr,DIRECT,no-resolve
  
  # 广告拦截
  - RULE-SET,reject,🛡️ 广告拦截
  
  # Telegram
  - RULE-SET,telegramcidr,📲 电报消息,no-resolve
  - DOMAIN-SUFFIX,t.me,📲 电报消息
  - DOMAIN-SUFFIX,tdesktop.com,📲 电报消息
  - DOMAIN-SUFFIX,telegra.ph,📲 电报消息
  - DOMAIN-SUFFIX,telegram.me,📲 电报消息
  - DOMAIN-SUFFIX,telegram.org,📲 电报消息
  
  # Netflix
  - DOMAIN-SUFFIX,netflix.com,🎥 Netflix
  - DOMAIN-SUFFIX,netflix.net,🎥 Netflix
  - DOMAIN-SUFFIX,nflxext.com,🎥 Netflix
  - DOMAIN-SUFFIX,nflximg.com,🎥 Netflix
  - DOMAIN-SUFFIX,nflxso.net,🎥 Netflix
  - DOMAIN-SUFFIX,nflxvideo.net,🎥 Netflix
  - DOMAIN-KEYWORD,netflix,🎥 Netflix
  
  # Disney+
  - DOMAIN-SUFFIX,disneyplus.com,🎬 Disney+
  - DOMAIN-SUFFIX,disney-plus.net,🎬 Disney+
  - DOMAIN-SUFFIX,disneystreaming.com,🎬 Disney+
  - DOMAIN-SUFFIX,dssott.com,🎬 Disney+
  - DOMAIN-KEYWORD,disney,🎬 Disney+
  
  # YouTube
  - DOMAIN-SUFFIX,youtube.com,📹 YouTube
  - DOMAIN-SUFFIX,googlevideo.com,📹 YouTube
  - DOMAIN-SUFFIX,ytimg.com,📹 YouTube
  - DOMAIN-SUFFIX,youtu.be,📹 YouTube
  - DOMAIN-KEYWORD,youtube,📹 YouTube
  
  # Spotify
  - DOMAIN-SUFFIX,spotify.com,🎵 Spotify
  - DOMAIN-SUFFIX,scdn.co,🎵 Spotify
  - DOMAIN-SUFFIX,spotilocal.com,🎵 Spotify
  - DOMAIN-KEYWORD,spotify,🎵 Spotify
  
  # OpenAI / ChatGPT
  - RULE-SET,openai,🌍 国外流量
  - DOMAIN-SUFFIX,openai.com,🌍 国外流量
  - DOMAIN-SUFFIX,ai.com,🌍 国外流量
  - DOMAIN-KEYWORD,openai,🌍 国外流量
  
  # 游戏平台
  - RULE-SET,games,🎮 游戏平台
  - DOMAIN-SUFFIX,steam.com,🎮 游戏平台
  - DOMAIN-SUFFIX,steampowered.com,🎮 游戏平台
  - DOMAIN-SUFFIX,steamcommunity.com,🎮 游戏平台
  - DOMAIN-SUFFIX,epicgames.com,🎮 游戏平台
  - DOMAIN-SUFFIX,battlenet.com,🎮 游戏平台
  - DOMAIN-KEYWORD,steam,🎮 游戏平台
  
  # 苹果服务
  - RULE-SET,icloud,🍎 苹果服务
  - RULE-SET,apple,🍎 苹果服务
  
  # 微软服务
  - RULE-SET,microsoft,Ⓜ️ 微软服务
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

---

## 配置说明

### 1. Smart 策略详解

#### 💡 智能选择 (url-test)
- **功能**：自动测试所有节点延迟，选择最快的
- **适用**：日常使用、对速度要求高
- **参数**：
  - `tolerance: 50` - 延迟容差 50ms，差距小于这个值不切换
  - `interval: 300` - 每 5 分钟测试一次

#### ⚖️ 负载均衡 (load-balance)
- **功能**：在多个节点间分配流量
- **适用**：下载大文件、多任务
- **策略**：
  - `consistent-hashing` - 同域名使用同节点（保持会话）
  - `round-robin` - 轮询（完全平均分配）

#### 🔄 故障转移 (fallback)
- **功能**：主节点故障时自动切换备用
- **适用**：稳定性要求高的场景
- **顺序**：按 `use` 列表顺序依次尝试

---

## 多机场配置

### 添加多个机场订阅

```yaml
proxy-providers:
  airport-1:
    url: "你的机场1订阅链接"
  airport-2:
    url: "你的机场2订阅链接"
  airport-3:
    url: "你的机场3订阅链接"
```

### 使用技巧

1. **主力 + 备用组合**
   ```yaml
   - name: "🔄 故障转移"
     use:
       - airport-1    # 主力机场（速度快）
       - airport-2    # 备用机场（稳定）
   ```

2. **混合使用**
   ```yaml
   - name: "💡 智能选择"
     use:
       - airport-1    # 包含所有机场节点
       - airport-2
       - airport-3
   ```

3. **分场景使用**
   ```yaml
   # 流媒体专用机场
   - name: "🎥 Netflix"
     proxies:
       - "机场3-香港-流媒体"
   ```

---

## 动态规则更新

### 自动更新机制

配置文件中的 `interval` 参数控制更新频率：

```yaml
rule-providers:
  reject:
    interval: 86400    # 24小时自动更新
```

### 手动更新规则

```bash
# 方法 1：通过 API
curl -X PUT http://10.0.0.4:9090/providers/rules

# 方法 2：重启服务
sudo systemctl restart mihomo

# 方法 3：热重载配置
curl -X PUT http://10.0.0.4:9090/configs -H "Content-Type: application/json" -d '{"path":"/etc/mihomo/config.yaml"}'
```

### 查看规则状态

```bash
# 查看所有规则集状态
curl http://10.0.0.4:9090/providers/rules

# 查看特定规则集
curl http://10.0.0.4:9090/providers/rules/reject
```

---

## 完整部署步骤

### 1. 备份原配置

```bash
# SSH 连接到 mihomo VM (10.0.0.4)
sudo cp /etc/mihomo/config.yaml /etc/mihomo/config.yaml.backup-$(date +%Y%m%d)
```

### 2. 应用新配置

```bash
# 下载智能配置
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/docs/SMART-CONFIG.md -o smart-config.md

# 复制配置内容到 /etc/mihomo/config.yaml
sudo nano /etc/mihomo/config.yaml

# ⚠️ 重要：修改以下内容
# 1. 机场订阅地址（proxy-providers）
# 2. API 密钥（secret）
```

### 3. 验证配置

```bash
# 检查配置语法
mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml

# 如果有错误，查看详细信息
mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml 2>&1 | grep -i error
```

### 4. 重启服务

```bash
sudo systemctl restart mihomo

# 查看启动状态
sudo systemctl status mihomo

# 实时查看日志
journalctl -u mihomo -f
```

### 5. 测试功能

```bash
# 测试代理连接
curl -x http://10.0.0.4:7890 http://www.gstatic.com/generate_204
echo $?  # 输出 0 表示成功

# 测试智能选择
curl -x http://10.0.0.4:7890 https://www.google.com -I

# 查看当前使用的节点
curl http://10.0.0.4:9090/proxies
```

---

## Web 管理面板（可选）

mihomo 支持通过 Web 界面管理，推荐使用 Yacd 或 Clash Dashboard。

### 1. 安装 Yacd Dashboard

```bash
# 创建 Web UI 目录
sudo mkdir -p /opt/mihomo/ui

# 下载 Yacd
cd /opt/mihomo/ui
sudo wget https://github.com/haishanh/yacd/releases/latest/download/yacd.tar.xz
sudo tar -xvf yacd.tar.xz
sudo rm yacd.tar.xz

# 配置 mihomo 使用 UI
sudo nano /etc/mihomo/config.yaml
```

在配置文件中添加：

```yaml
external-controller: 0.0.0.0:9090
external-ui: /opt/mihomo/ui
secret: "your-secret-here"
```

### 2. 访问 Web 界面

浏览器打开：`http://10.0.0.4:9090/ui`

输入 API 密钥后即可管理：
- 查看所有节点
- 实时切换节点
- 查看延迟测试
- 查看连接统计

---

## 高级技巧

### 1. 按延迟分组

```yaml
- name: "⚡ 低延迟节点"
  type: url-test
  tolerance: 20
  use:
    - airport-1
  filter: ".*"    # 匹配所有节点
  # 自动筛选延迟 < 100ms 的节点
```

### 2. 按流量分组

```yaml
# 大流量下载专用（负载均衡）
- name: "📥 下载专用"
  type: load-balance
  strategy: round-robin
  use:
    - airport-1
    - airport-2
  filter: "(?i)IEPL|专线|Premium"
```

### 3. 智能 DNS 分流

```yaml
dns:
  nameserver-policy:
    # 国内域名使用国内 DNS
    "geosite:cn": [223.5.5.5, 119.29.29.29]
    # 国外域名使用代理 DNS
    "geosite:geolocation-!cn":
      - https://dns.google/dns-query
      - https://cloudflare-dns.com/dns-query
```

### 4. 自定义规则

在配置文件的 `rules` 部分添加：

```yaml
rules:
  # 自定义直连域名
  - DOMAIN-SUFFIX,example.com,DIRECT
  - DOMAIN-KEYWORD,mysite,DIRECT
  
  # 自定义代理域名
  - DOMAIN-SUFFIX,blocked.com,🚀 节点选择
  
  # IP 地址规则
  - IP-CIDR,192.168.1.0/24,DIRECT
  - IP-CIDR6,2001:db8::/32,DIRECT
  
  # 进程规则（仅支持部分平台）
  - PROCESS-NAME,v2ray,DIRECT
  - PROCESS-NAME,chrome,🚀 节点选择
```

---

## 性能优化

### 1. 调整健康检查频率

```yaml
proxy-providers:
  airport-1:
    health-check:
      interval: 300      # 降低到 5 分钟（默认 10 分钟）
      lazy: true         # 启用懒加载（仅使用时检查）
```

### 2. 启用节点过滤

```yaml
proxy-groups:
  - name: "🇭🇰 香港节点"
    filter: "(?i)港|hk|hongkong"  # 只显示香港节点
```

### 3. 优化规则匹配

```yaml
# 高频域名放前面
rules:
  - DOMAIN-SUFFIX,google.com,🌍 国外流量
  - DOMAIN-SUFFIX,youtube.com,📹 YouTube
  - RULE-SET,gfw,🌍 国外流量      # 规则集放后面
```

---

## 监控与调试

### 查看实时连接

```bash
# 所有活动连接
curl http://10.0.0.4:9090/connections

# 查看特定代理组
curl http://10.0.0.4:9090/proxies/💡%20智能选择
```

### 查看延迟测试

```bash
# 测试所有节点
curl -X GET http://10.0.0.4:9090/proxies -H "Authorization: Bearer your-secret"

# 手动触发延迟测试
curl -X GET "http://10.0.0.4:9090/group/💡%20智能选择/delay?timeout=5000&url=http://www.gstatic.com/generate_204"
```

### 查看规则匹配

```bash
# 查看规则命中统计
curl http://10.0.0.4:9090/rules

# 测试域名匹配哪条规则
# 查看日志即可看到匹配结果
journalctl -u mihomo -f | grep "match"
```

---

## 故障排查

### 问题 1：节点延迟测试失败

```bash
# 检查健康检查 URL 是否可访问
curl -x http://10.0.0.4:7890 http://www.gstatic.com/generate_204

# 如果不通，更换测试 URL
# 在配置文件中修改：
url: http://cp.cloudflare.com/generate_204
```

### 问题 2：规则不生效

```bash
# 检查规则集是否下载成功
ls -lh /etc/mihomo/ruleset/

# 手动更新规则集
curl -X PUT http://10.0.0.4:9090/providers/rules

# 查看日志中的规则匹配
journalctl -u mihomo -n 100 | grep -i rule
```

### 问题 3：负载均衡不均匀

```bash
# 检查策略类型
curl http://10.0.0.4:9090/proxies/⚖️%20负载均衡

# 尝试更换策略
strategy: round-robin  # 完全轮询
# 或
strategy: consistent-hashing  # 一致性哈希
```

---

## 完成！🎉

现在你拥有：

✅ **💡 智能选择** - 自动选最快节点  
✅ **⚖️ 负载均衡** - 多节点分流，带宽叠加  
✅ **🔄 故障转移** - 自动切换备用节点  
✅ **🌐 多机场支持** - 3 个机场随意切换  
✅ **📊 动态规则** - 自动更新，无需手动维护  
✅ **🎯 Web 管理** - 可视化界面，实时监控  

**推荐配置：**
- 日常使用：`💡 智能选择`
- 下载任务：`⚖️ 负载均衡`
- 稳定连接：`🔄 故障转移`

**下一步：**
1. 替换机场订阅地址
2. 设置 API 密钥
3. 安装 Web 管理界面
4. 享受智能分流！

