# BoomDNS 快速参考

常用命令速查表

---

## 服务管理

### mihomo
```bash
# 状态检查
systemctl status mihomo

# 重启服务
systemctl restart mihomo

# 查看日志
journalctl -u mihomo -n 50
journalctl -u mihomo -f        # 实时日志

# 测试代理
curl -x http://127.0.0.1:7890 https://www.google.com -I

# 更新版本
/opt/mihomo/update-mihomo.sh
```

### AdGuard Home
```bash
# 状态检查
systemctl status AdGuardHome

# 重启服务
systemctl restart AdGuardHome

# 查看日志
journalctl -u AdGuardHome -n 50

# Web 管理
http://10.0.0.5
```

---

## 配置文件位置

```bash
# mihomo 配置
/etc/mihomo/config.yaml

# mihomo 订阅
/etc/mihomo/providers/

# mihomo 规则
/etc/mihomo/ruleset/

# AdGuard Home 配置
/opt/AdGuardHome/AdGuardHome.yaml
```

---

## 测试命令

### DNS 测试
```bash
# 测试 DNS 解析
nslookup google.com 10.0.0.5

# 测试广告拦截
curl -I http://ad.doubleclick.net
```

### 代理测试
```bash
# HTTP 代理
curl -x http://10.0.0.4:7890 https://www.google.com -I

# SOCKS5 代理
curl --socks5 10.0.0.4:7891 https://www.google.com -I

# 查看 IP
curl -x http://10.0.0.4:7890 https://ip.sb
```

### 网络测试
```bash
# Ping 测试
ping 10.0.0.4          # mihomo
ping 10.0.0.5          # AdGuard Home

# 端口测试
telnet 10.0.0.4 7890   # mihomo HTTP
telnet 10.0.0.5 53     # AdGuard DNS
```

---

## RouterOS 常用命令

### DNS
```bash
# 查看 DNS 配置
/ip dns print

# 查看 DNS 缓存
/ip dns cache print

# 清空 DNS 缓存
/ip dns cache flush
```

### DHCP
```bash
# 查看 DHCP 服务器
/ip dhcp-server print

# 查看 DHCP 租约
/ip dhcp-server lease print
```

### 防火墙
```bash
# 查看 NAT 规则
/ip firewall nat print

# 查看 Filter 规则
/ip firewall filter print

# 查看活动连接
/ip firewall connection print count-only
```

### 日志
```bash
# 查看系统日志
/log print

# 查看 DNS 日志
/log print where topics~"dns"

# 查看防火墙日志
/log print where topics~"firewall"
```

---

## API 管理

### mihomo API
```bash
# 查看所有代理
curl http://10.0.0.4:9090/proxies

# 更新订阅
curl -X PUT http://10.0.0.4:9090/providers/proxies/main-airport

# 更新规则
curl -X PUT http://10.0.0.4:9090/providers/rules

# 查看连接
curl http://10.0.0.4:9090/connections
```

---

## 备份命令

### 备份配置
```bash
# mihomo
tar -czf ~/mihomo-backup-$(date +%Y%m%d).tar.gz /etc/mihomo

# AdGuard Home
tar -czf ~/adguard-backup-$(date +%Y%m%d).tar.gz /opt/AdGuardHome

# RouterOS
/export file=router-backup-$(date +%Y%m%d)
/system backup save name=router-backup-$(date +%Y%m%d)
```

### 恢复配置
```bash
# mihomo
tar -xzf ~/mihomo-backup-*.tar.gz -C /
systemctl restart mihomo

# AdGuard Home
systemctl stop AdGuardHome
tar -xzf ~/adguard-backup-*.tar.gz -C /
systemctl start AdGuardHome

# RouterOS
/import file=router-backup-*.rsc
```

---

## 故障排查

### mihomo 不工作
```bash
# 1. 检查服务
systemctl status mihomo

# 2. 检查配置
mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml

# 3. 查看日志
journalctl -u mihomo -n 50

# 4. 检查订阅
ls -lh /etc/mihomo/providers/
cat /etc/mihomo/providers/main.yaml | head -20

# 5. 手动更新订阅
curl -X PUT http://10.0.0.4:9090/providers/proxies/main-airport
```

### AdGuard Home 不工作
```bash
# 1. 检查服务
systemctl status AdGuardHome

# 2. 测试 DNS
nslookup google.com 10.0.0.5

# 3. 查看日志
journalctl -u AdGuardHome -n 50

# 4. 检查端口
netstat -tulpn | grep 53
```

### 无法上网
```bash
# 1. 检查网络连接
ping 8.8.8.8

# 2. 检查 DNS
nslookup google.com

# 3. RouterOS 检查
# 登录 RouterOS
/ip dns print
/ip route print

# 4. 临时禁用 DNS 劫持
/ip firewall nat disable [find comment="DNS Hijack"]
```

---

## 性能监控

### 系统资源
```bash
# mihomo VM
ssh root@10.0.0.4
top
htop
df -h
free -h

# AdGuard Home VM
ssh root@10.0.0.5
top
df -h
```

### 网络流量
```bash
# RouterOS
/interface monitor-traffic ether1

# 连接数
/ip firewall connection print count-only

# 系统资源
/system resource print
```

---

## 更新操作

### 更新 mihomo
```bash
ssh root@10.0.0.4
/opt/mihomo/update-mihomo.sh
```

### 更新 AdGuard Home
```
浏览器打开: http://10.0.0.5
设置 → 常规设置 → 检查更新
```

### 更新 RouterOS
```bash
# 检查更新
/system package update check-for-updates

# 下载更新
/system package update download

# 安装更新（会重启）
/system reboot
```

---

## 快速访问

| 服务 | 地址 | 用途 |
|------|------|------|
| mihomo API | http://10.0.0.4:9090 | 节点管理 |
| AdGuard Home | http://10.0.0.5 | DNS 管理 |
| RouterOS Winbox | winbox://路由器IP | 路由器管理 |

---

## 紧急处理

### 完全重置（慎用）
```bash
# mihomo 重置
ssh root@10.0.0.4
systemctl stop mihomo
rm -rf /etc/mihomo/providers/*
rm -rf /etc/mihomo/ruleset/*
systemctl start mihomo

# AdGuard Home 重置
ssh root@10.0.0.5
systemctl stop AdGuardHome
rm /opt/AdGuardHome/AdGuardHome.yaml
systemctl start AdGuardHome
# 浏览器重新初始化: http://10.0.0.5:3000

# RouterOS 重置（非常慎重！）
/system reset-configuration
```

---

**提示：** 建议收藏此页面，日常维护时快速查找命令

