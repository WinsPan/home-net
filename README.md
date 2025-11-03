# BoomDNS

**智能分流 + 广告过滤 + 容错保护**的完整家庭网络解决方案

一个命令，自动部署

---

## 快速了解

```
设备 → RouterOS → mihomo → AdGuard Home → 互联网
         ↓          ↓            ↓
     DNS劫持    智能分流      广告过滤
```

**三个核心服务：**
- 🚀 **mihomo** (10.0.0.4) - 智能代理和分流
- 🛡️ **AdGuard Home** (10.0.0.5) - DNS 广告过滤
- 🌐 **RouterOS** (10.0.0.2) - 网关和容错

---

## 三步部署

### 1. 安装 mihomo

```bash
# 创建 Debian 12 VM (10.0.0.4, 2C2G, 20GB)
# SSH 连接后执行：

curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh | bash

# 选择: 1 (智能配置)
# 输入: 你的机场订阅地址
```

### 2. 安装 AdGuard Home

```bash
# 创建 Debian 12 VM (10.0.0.5, 1C1G, 10GB)
# SSH 连接后执行：

curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh | bash

# 浏览器打开: http://10.0.0.5:3000
# 完成初始化向导
```

### 3. 配置 RouterOS

```bash
# 连接 RouterOS，复制粘贴：

/ip dns set servers=10.0.0.5,223.5.5.5,119.29.29.29
/ip pool add name=dhcp-pool ranges=10.0.0.100-10.0.0.200
/ip dhcp-server add name=dhcp1 interface=bridge address-pool=dhcp-pool
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.2 dns-server=10.0.0.5,223.5.5.5,119.29.29.29
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 dst-address=!10.0.0.5 action=dst-nat to-addresses=10.0.0.5 comment="DNS Hijack"
```

### 4. 设置代理（任选其一）

**方式 A：手动设置（推荐）**
- 设备代理设置：`10.0.0.4:7890`
- 或安装浏览器扩展：SwitchyOmega

**方式 B：透明代理（高级）**
- 查看 [完整部署指南](GUIDE.md)

---

## 完成！🎉

**测试验证：**
- ✅ 访问 http://testadblock.com 查看广告拦截
- ✅ 访问 https://www.google.com 测试代理
- ✅ 访问 http://10.0.0.4:9090 管理 mihomo
- ✅ 访问 http://10.0.0.5 管理 AdGuard Home

---

## 📚 文档

### 新手必读
- **[完整部署指南](GUIDE.md)** ⭐ **强烈推荐 - 详细的分步指南**
- **[快速参考卡片](CHEATSHEET.md)** 🔖 **常用命令速查**

### 实用工具
- **验证部署** - `bash scripts/verify-deployment.sh` - 自动测试所有功能
- **故障诊断** - `bash scripts/diagnose.sh` - 自动诊断问题并给出解决方案

### 进阶配置
- [完整配置文档](docs/CONFIG.md) - mihomo + AdGuard Home + RouterOS 详细配置
- [RouterOS 配置](docs/ROUTEROS.md) - 路由器高级功能

### 参考
- [更新日志](CHANGELOG.md)
- [贡献指南](CONTRIBUTING.md)

---

## 核心特性

### 💡 智能分流
- **Smart 策略** - 自动选择最快节点
- **负载均衡** - 多节点带宽叠加
- **故障转移** - 自动切换备用节点
- **地区分组** - 香港/新加坡/日本/美国

### 🛡️ 广告过滤
- **DNS 级别** - 全设备生效
- **多规则源** - Anti-AD + EasyList China
- **自动更新** - 规则定时同步
- **白名单** - 防止误拦截

### 🔄 容错保护
- **多 DNS 备份** - 服务故障自动切换
- **健康检查** - RouterOS 自动监控
- **零中断** - 任何服务挂掉都不影响上网

---

## 技术栈

- **Proxmox VE 8+** - 虚拟化平台
- **Debian 12** - 操作系统
- **mihomo** - Clash Meta 代理内核
- **AdGuard Home** - DNS 服务器
- **RouterOS 7+** - MikroTik 路由器系统

---

## 常见问题

**Q: 需要什么硬件？**
- Proxmox VE 服务器（任意配置）
- MikroTik 路由器（支持 RouterOS 7+）
- 机场订阅（1 个即可）

**Q: 多久能部署完成？**
- 跟着 [完整部署指南](GUIDE.md) 操作：30-60 分钟
- 有经验的用户：15-30 分钟

**Q: 服务挂掉会断网吗？**
- 不会！已配置容错机制
- mihomo 挂掉：失去代理功能，DNS 和上网正常
- AdGuard 挂掉：失去广告过滤，自动切换备用 DNS
- RouterOS 自动监控并切换

**Q: 需要手动维护吗？**
- 订阅自动更新（每小时）
- 规则自动更新（每天）
- 只需偶尔升级软件版本

**Q: 支持哪些设备？**
- Windows / macOS / Linux
- iOS / Android
- 智能电视 / 游戏机
- 所有支持代理设置的设备

---

## 故障排查

### 无法上网
```bash
# RouterOS 检查
/ip dns print
# 应该显示: 10.0.0.5,223.5.5.5,119.29.29.29

# 临时禁用 DNS 劫持
/ip firewall nat disable [find comment="DNS Hijack"]
```

### 广告未拦截
```
1. 访问 http://10.0.0.5
2. 过滤器 → 立即更新过滤器
3. 清除浏览器 DNS 缓存
```

### 代理不工作
```bash
# 检查 mihomo
ssh root@10.0.0.4
systemctl status mihomo
journalctl -u mihomo -n 50

# 测试代理
curl -x http://10.0.0.4:7890 https://www.google.com -I
```

**更多问题？** 查看 [完整部署指南](GUIDE.md) 的故障排查章节

---

## 维护

### 更新服务
```bash
# mihomo
ssh root@10.0.0.4
/opt/mihomo/update-mihomo.sh

# AdGuard Home
# 浏览器: http://10.0.0.5 → 设置 → 检查更新
```

### 备份配置
```bash
# mihomo
ssh root@10.0.0.4
tar -czf ~/mihomo-backup.tar.gz /etc/mihomo

# AdGuard Home
ssh root@10.0.0.5
tar -czf ~/adguard-backup.tar.gz /opt/AdGuardHome

# RouterOS
/export file=router-backup
```

---

## 参与贡献

欢迎提交 Issue 和 Pull Request！

查看 [贡献指南](CONTRIBUTING.md)

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

## 致谢

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) - Clash Meta 内核
- [AdguardTeam/AdGuardHome](https://github.com/AdguardTeam/AdGuardHome) - DNS 服务器
- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) - 分流规则
- [privacy-protection-tools/anti-AD](https://github.com/privacy-protection-tools/anti-AD) - 广告规则
- [666OS/YYDS](https://github.com/666OS/YYDS) - 配置参考

---

## Star History

⭐ 如果这个项目对你有帮助，欢迎 Star！

---

**快速开始** → [完整部署指南](GUIDE.md)
