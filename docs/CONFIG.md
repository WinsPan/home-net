# 完整配置

mihomo + AdGuard Home + RouterOS 配置指南

---

## 网络架构

```
客户端 → RouterOS (10.0.0.2) → AdGuard (10.0.0.4) → 互联网
                 ↓
            mihomo (10.0.0.3) 代理
```

**IP 规划：**
- RouterOS: 10.0.0.2
- mihomo: 10.0.0.3
- AdGuard Home: 10.0.0.4

---

## mihomo 配置

### 完整配置文件

位置：`/etc/mihomo/config.yaml`

```yaml
# 基础配置
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090

# DNS
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://dns.google/dns-query

# 订阅
proxy-providers:
  airport:
    type: http
    url: "你的订阅地址"
    interval: 86400
    path: ./proxies/airport.yaml
    health-check:
      enable: true
      url: http://www.gstatic.com/generate_204
      interval: 300

# 代理组
proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - DIRECT
    use:
      - airport

  - name: 自动选择
    type: url-test
    use:
      - airport
    url: http://www.gstatic.com/generate_204
    interval: 300

# 规则
rules:
  # 广告拦截
  - DOMAIN-SUFFIX,doubleclick.net,REJECT
  - DOMAIN-SUFFIX,googleadservices.com,REJECT
  
  # 国内直连
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-KEYWORD,baidu,DIRECT
  - DOMAIN-KEYWORD,taobao,DIRECT
  - DOMAIN-KEYWORD,alipay,DIRECT
  - GEOIP,CN,DIRECT
  - GEOIP,PRIVATE,DIRECT
  
  # 国外代理
  - DOMAIN-SUFFIX,google.com,节点选择
  - DOMAIN-SUFFIX,youtube.com,节点选择
  - DOMAIN-SUFFIX,facebook.com,节点选择
  - DOMAIN-SUFFIX,twitter.com,节点选择
  - DOMAIN-SUFFIX,github.com,节点选择
  
  # 默认
  - MATCH,节点选择
```

### 订阅配置参考

参考：https://github.com/666OS/YYDS/tree/main/mihomo

### 更新订阅

```bash
ssh root@10.0.0.3
bash /root/scripts/update-mihomo.sh
```

---

## AdGuard Home 配置

### Web 初始化

1. 访问：http://10.0.0.4:3000
2. 设置管理员账号密码
3. 监听端口保持默认（53）

### DNS 设置

**上游 DNS：**
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
223.5.5.5
119.29.29.29
```

**Bootstrap DNS：**
```
223.5.5.5
119.29.29.29
```

### 过滤规则

**推荐规则：**
```
# 反广告
https://anti-ad.net/easylist.txt

# AdGuard 规则
https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_2_Base/filter.txt
https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_15_DnsFilter/filter.txt

# 中文规则
https://raw.githubusercontent.com/Aethersailor/Custom_OpenClash_Rules/main/rule_provider/adblock4.yaml
```

---

## RouterOS 配置

### 完整配置脚本

部署后会自动生成 `routeros-config.rsc`，在 RouterOS 执行：

```routeros
# DNS 配置
/ip dns set servers=10.0.0.4,223.5.5.5,119.29.29.29

# DHCP 配置
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.4

# DNS 劫持（强制使用 AdGuard）
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 dst-address=!10.0.0.4 action=dst-nat to-addresses=10.0.0.4 comment="DNS Hijack"

# 防火墙
/ip firewall filter add chain=input connection-state=established,related action=accept
/ip firewall filter add chain=input src-address=10.0.0.0/24 action=accept
/ip firewall filter add chain=input action=drop

# NAT（上网）
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade

# 健康检查（容错）
/system script add name=check-adguard source={
    :if ([/ping 10.0.0.4 count=2] = 0) do={
        /ip firewall nat disable [find comment="DNS Hijack"]
    } else={
        /ip firewall nat enable [find comment="DNS Hijack"]
    }
}
/system scheduler add name=check-schedule on-event=check-adguard interval=1m
```

### 透明代理配置

如需全局透明代理（高级）：

```routeros
# 标记代理流量
/ip firewall mangle add chain=prerouting src-address=10.0.0.0/24 src-address-list=!no-proxy action=mark-routing new-routing-mark=proxy-route passthrough=yes

# 路由到 mihomo
/ip route add dst-address=0.0.0.0/0 gateway=10.0.0.3 routing-mark=proxy-route

# 重定向到 mihomo
/ip firewall nat add chain=dstnat protocol=tcp src-address=10.0.0.0/24 action=dst-nat to-addresses=10.0.0.3 to-ports=7890

# 排除列表（不需要代理的设备）
/ip firewall address-list add list=no-proxy address=10.0.0.1
/ip firewall address-list add list=no-proxy address=10.0.0.2
```

---

## 代理配置

### 方式 1：手动代理（推荐）

在客户端设置：
- 代理服务器：`10.0.0.3`
- 代理端口：`7890`

**各平台设置：**

**Windows：**
```
设置 → 网络和Internet → 代理 → 手动设置代理
服务器：10.0.0.3
端口：7890
```

**macOS：**
```
系统偏好设置 → 网络 → 高级 → 代理
HTTP 代理：10.0.0.3:7890
HTTPS 代理：10.0.0.3:7890
```

**iOS/Android：**
```
WiFi 设置 → 配置代理 → 手动
服务器：10.0.0.3
端口：7890
```

### 方式 2：透明代理（高级）

参考上面 RouterOS 透明代理配置。

---

## 测试验证

### 快速测试

```bash
# 自动测试
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/test-deployment.sh | bash
```

### 手动测试

```bash
# 测试代理
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 测试 DNS
nslookup google.com 10.0.0.4

# 测试分流
curl -x http://10.0.0.3:7890 http://ip.sb  # 应该是代理 IP
curl http://ip.sb  # 应该是本地 IP
```

### 管理界面

```
mihomo 面板:   http://10.0.0.3:9090
AdGuard Home:  http://10.0.0.4:3000
```

---

## 维护

### 更新 mihomo

```bash
ssh root@10.0.0.3
bash /root/scripts/update-mihomo.sh
```

### 查看日志

```bash
# mihomo
journalctl -u mihomo -f

# AdGuard Home
journalctl -u AdGuardHome -f
```

### 备份配置

```bash
# mihomo
scp root@10.0.0.3:/etc/mihomo/config.yaml ./backup/

# AdGuard Home
scp root@10.0.0.4:/opt/AdGuardHome/AdGuardHome.yaml ./backup/
```

---

## 常见问题

### Q: 无法访问外网？

A: 检查步骤：
1. `curl -x http://10.0.0.3:7890 https://www.google.com -I` - 测试代理
2. 检查 mihomo 订阅是否有效
3. 检查节点是否可用

### Q: 广告过滤不生效？

A: 检查步骤：
1. AdGuard Home 规则是否更新
2. RouterOS DNS 是否指向 10.0.0.4
3. 客户端 DNS 是否正确

### Q: 代理很慢？

A: 优化方法：
1. 切换更快的节点
2. 使用 url-test 自动选择
3. 检查网络带宽

### Q: 如何添加新节点？

A: 
1. 更新订阅地址
2. 或手动添加到 config.yaml 的 proxies 部分
3. 重启 mihomo：`systemctl restart mihomo`

---

**部署完成！** 🎉
