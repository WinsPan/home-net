# 快速参考 - 基于您的网络环境

本文档基于您的具体网络规划提供快速参考。

## 🌐 您的网络规划

```
设备              IP地址      功能
───────────────────────────────────────
RouterOS         10.0.0.2    主路由
mihomo VM        10.0.0.4    智能代理
AdGuard Home VM  10.0.0.5    广告过滤
```

## 🚀 快速部署步骤

### 第一步：创建 mihomo 虚拟机

1. **在 Proxmox 创建 VM**
   - VM ID: 100
   - 名称: mihomo
   - 系统: Debian 12
   - CPU: 2核
   - 内存: 2048MB
   - 磁盘: 16GB

2. **配置静态 IP**
   ```bash
   nano /etc/network/interfaces
   ```
   ```
   auto ens18
   iface ens18 inet static
       address 10.0.0.4
       netmask 255.255.255.0
       gateway 10.0.0.2
       dns-nameservers 223.5.5.5
   ```

3. **安装 mihomo**
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh)
   ```

4. **配置代理节点**
   ```bash
   nano /etc/mihomo/config.yaml
   # 添加您的代理节点
   systemctl restart mihomo
   ```

### 第二步：创建 AdGuard Home 虚拟机

1. **在 Proxmox 创建 VM**
   - VM ID: 101
   - 名称: adguardhome
   - 系统: Debian 12
   - CPU: 2核
   - 内存: 1024MB
   - 磁盘: 16GB

2. **配置静态 IP**
   ```bash
   nano /etc/network/interfaces
   ```
   ```
   auto ens18
   iface ens18 inet static
       address 10.0.0.5
       netmask 255.255.255.0
       gateway 10.0.0.2
       dns-nameservers 223.5.5.5
   ```

3. **安装 AdGuard Home**
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh)
   ```

4. **初始化配置**
   - 访问: http://10.0.0.5:3000
   - 设置管理员账号密码
   - **上游 DNS 设置为**: 10.0.0.4:53
   - 添加广告过滤规则

### 第三步：配置 RouterOS

```bash
# 在 RouterOS Terminal 执行

# 1. 设置路由器 DNS
/ip dns set servers=10.0.0.5

# 2. 设置 DHCP 分发 DNS
/ip dhcp-server network set [find] dns-server=10.0.0.5

# 3. 绑定虚拟机静态 IP（替换 MAC 地址）
/ip dhcp-server lease add address=10.0.0.4 mac-address=mihomo的MAC comment="mihomo VM"
/ip dhcp-server lease add address=10.0.0.5 mac-address=adguard的MAC comment="AdGuard Home VM"

# 4. 添加静态 DNS 记录（可选）
/ip dns static add name=mihomo.home address=10.0.0.4
/ip dns static add name=adguard.home address=10.0.0.5
```

## ✅ 验证清单

### 1. 网络连通性
```bash
# 在 RouterOS
/ping 10.0.0.4 count=5
/ping 10.0.0.5 count=5

# 在 mihomo VM
ping 10.0.0.2
ping 10.0.0.5

# 在 AdGuard Home VM
ping 10.0.0.2
ping 10.0.0.4
```

### 2. DNS 解析
```bash
# 在客户端设备
nslookup google.com
nslookup baidu.com
```

### 3. 广告拦截
- 访问: https://ads-blocker.com/zh-CN/testing/
- 应该看到大部分广告被拦截

### 4. 服务状态
```bash
# mihomo VM
systemctl status mihomo

# AdGuard Home VM
/opt/AdGuardHome/AdGuardHome -s status
```

## 📊 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| AdGuard Home 管理 | http://10.0.0.5:3000 | Web 管理界面 |
| mihomo 控制面板 | http://10.0.0.4:9090 | RESTful API |
| Yacd 面板 | http://yacd.metacubex.one | 使用 API: http://10.0.0.4:9090 |

## 🔧 常用命令

### mihomo VM

```bash
# 服务管理
systemctl start mihomo
systemctl stop mihomo
systemctl restart mihomo
systemctl status mihomo

# 查看日志
journalctl -u mihomo -f

# 编辑配置
nano /etc/mihomo/config.yaml

# 测试配置
/usr/local/bin/mihomo -d /etc/mihomo -t
```

### AdGuard Home VM

```bash
# 服务管理
/opt/AdGuardHome/AdGuardHome -s start
/opt/AdGuardHome/AdGuardHome -s stop
/opt/AdGuardHome/AdGuardHome -s restart
/opt/AdGuardHome/AdGuardHome -s status

# 查看日志
journalctl -f | grep AdGuardHome
```

### RouterOS

```bash
# 查看 DNS 设置
/ip dns print

# 查看 DHCP 租约
/ip dhcp-server lease print

# 查看 DNS 缓存
/ip dns cache print

# 测试 DNS
/tool fetch url=http://www.google.com mode=http
```

## 🚨 常见问题快速解决

### 问题：无法上网
```bash
# 1. 检查 DNS 配置
/ip dns print

# 2. 检查 DHCP 设置
/ip dhcp-server network print

# 3. 测试到虚拟机的连通性
/ping 10.0.0.4
/ping 10.0.0.5

# 4. 检查虚拟机服务状态
# 在各个 VM 上检查服务状态
```

### 问题：广告拦截不生效
```bash
# 1. 确认 AdGuard Home 上游 DNS 设置正确
# Web 界面 → 设置 → DNS 设置 → 上游 DNS 服务器
# 应该是: 10.0.0.4:53

# 2. 检查规则是否已添加
# Web 界面 → 设置 → DNS 封锁清单
# 应该有多条规则

# 3. 更新规则
# 点击 "更新" 按钮

# 4. 清除浏览器缓存
```

### 问题：代理不工作
```bash
# 1. 检查 mihomo 服务
systemctl status mihomo

# 2. 查看日志
journalctl -u mihomo -n 50

# 3. 测试配置文件
/usr/local/bin/mihomo -d /etc/mihomo -t

# 4. 检查代理节点
# 访问 Yacd 面板测试节点延迟
```

## 📋 配置文件位置

### mihomo VM
- 配置文件: `/etc/mihomo/config.yaml`
- 二进制文件: `/usr/local/bin/mihomo`
- 服务文件: `/etc/systemd/system/mihomo.service`

### AdGuard Home VM
- 安装目录: `/opt/AdGuardHome/`
- 配置文件: `/opt/AdGuardHome/AdGuardHome.yaml`
- 数据目录: `/opt/AdGuardHome/data/`

### RouterOS
- 配置备份: `/export file=backup`
- 通过 WinBox 或 WebFig 管理

## 🔄 备份命令

### mihomo
```bash
tar czf mihomo-backup-$(date +%Y%m%d).tar.gz /etc/mihomo
```

### AdGuard Home
```bash
tar czf adguard-backup-$(date +%Y%m%d).tar.gz /opt/AdGuardHome/data
```

### RouterOS
```bash
/export file=ros-backup-$(date +%Y%m%d)
```

## 📚 详细文档链接

- [完整部署指南](DEPLOYMENT-GUIDE.md) - 从零到完成的详细步骤
- [RouterOS 配置](ROUTEROS-CONFIG.md) - 深入的 ROS 配置
- [AdGuard 规则](adguardhome-rules.md) - 广告过滤规则详解
- [组合方案](INTEGRATION-GUIDE.md) - 整合使用指南
- [配置示例](config-examples.yaml) - mihomo 配置参考

## 💡 优化建议

1. ✅ **定期备份**: 每周备份配置文件
2. ✅ **更新规则**: 每月更新广告过滤规则
3. ✅ **监控性能**: 关注 VM 资源使用
4. ✅ **测试节点**: 定期测试代理节点可用性
5. ✅ **清理日志**: 定期清理旧日志文件

---

**数据流向示意**：
```
客户端设备 (自动获取 DNS: 10.0.0.5)
    ↓
AdGuard Home (10.0.0.5:53)
    ↓ 过滤广告
    ↓ 上游 DNS: 10.0.0.4:53
mihomo (10.0.0.4:53)
    ↓ 智能分流
    ├─ 国内域名 → 直连
    └─ 国外域名 → 代理服务器 → 互联网
```

**🎉 配置完成后即可享受干净、快速、安全的网络！**

