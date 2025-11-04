# 部署指南

## 📋 IP地址规划

```
RouterOS (主路由):  10.0.0.2
sing-box (代理):    10.0.0.3
AdGuard Home (DNS): 10.0.0.4
```

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
CPU: 2核
内存: 2048 MB
磁盘: 10 GB
IP: 10.0.0.4/24
网关: 10.0.0.2
root密码: ******
```

### 第二步：安装sing-box（在sing-box VM执行）

```bash
# SSH登录
ssh root@10.0.0.3

# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh -o install.sh

# 运行安装
bash install.sh

# 根据提示：
订阅地址: https://your-subscription-url
订阅格式 (1=sing-box, 2=Clash需转换) [1]: 2  # 如果是Clash订阅选2
```

### 第三步：安装AdGuard Home（在AdGuard Home VM执行）

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

## 🌐 RouterOS 配置

### DNS配置

```routeros
# 设置DHCP DNS为AdGuard Home
/ip dhcp-server network
set [find] dns-server=10.0.0.4

# 设置路由器自身DNS
/ip dns
set servers=10.0.0.4
set allow-remote-requests=yes
```

### 健康检查（可选）

```routeros
# 添加DNS健康检查
/tool netwatch
add host=10.0.0.4 interval=30s timeout=5s down-script={
  /ip dns set servers=223.5.5.5,8.8.8.8
} up-script={
  /ip dns set servers=10.0.0.4
}
```

### 透明代理（可选）

如果需要透明代理所有流量：

```routeros
# 1. 标记需要代理的流量
/ip firewall mangle
add chain=prerouting src-address=192.168.1.0/24 \
    dst-address-list=!china action=mark-routing new-routing-mark=proxy

# 2. 路由到sing-box
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.0.3 routing-mark=proxy

# 3. NAT配置
/ip firewall nat
add chain=srcnat out-interface-list=WAN action=masquerade
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

