# BoomDNS

智能分流 + 广告过滤 + 容错保护 的家庭网络解决方案

---

## 快速开始

### 一键部署（在 Proxmox 节点上运行）

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh

# 运行（需要 root 权限）
bash deploy.sh
```

**脚本会自动：**
- ✅ 创建 2 个 VM
- ✅ 安装 Debian 系统（需要手动完成安装向导）
- ✅ 配置网络
- ✅ 安装 mihomo + AdGuard Home
- ✅ 生成 RouterOS 配置

---

## 功能特性

- 🚀 **智能分流** - 国内外自动识别
- 🛡️ **广告过滤** - DNS 级别拦截
- 🔄 **容错保护** - 服务故障不断网
- ⚡ **一键部署** - 全自动化

---

## 架构

```
设备 → RouterOS → mihomo → AdGuard Home → 互联网
         ↓          ↓            ↓
     DNS劫持    智能分流      广告过滤
```

### 服务列表

| 服务 | IP | 端口 | 说明 |
|------|-----|------|------|
| RouterOS | 10.0.0.2 | - | 网关 |
| mihomo | 10.0.0.4 | 7890 | 代理 |
| AdGuard Home | 10.0.0.5 | 53 | DNS |

---

## 使用说明

### 1. 初始化 AdGuard Home

访问 `http://10.0.0.5:3000` 完成初始化

**DNS 设置：**
```
上游 DNS：
  https://doh.pub/dns-query
  https://dns.alidns.com/dns-query
  223.5.5.5
  119.29.29.29

Bootstrap DNS：
  223.5.5.5
  119.29.29.29
```

**过滤规则：**
```
Anti-AD: https://anti-ad.net/easylist.txt
AdGuard: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
EasyList: https://easylist-downloads.adblockplus.org/easylistchina.txt
```

### 2. 配置 RouterOS

打开生成的 `routeros-config.rsc`，复制内容到 RouterOS 执行

**注意修改 WAN 口名称！**

### 3. 设置设备代理

**方式 A：手动设置（推荐）**
- 代理地址：`10.0.0.4:7890`
- 浏览器推荐：SwitchyOmega 扩展

**方式 B：透明代理（高级）**
- 查看 [docs/CONFIG.md](docs/CONFIG.md)

---

## 测试验证

```bash
# 测试代理
curl -x http://10.0.0.4:7890 https://www.google.com -I

# 测试广告拦截
访问: http://testadblock.com

# 管理界面
mihomo:       http://10.0.0.4:9090
AdGuard Home: http://10.0.0.5
```

---

## 维护

### 更新 mihomo
```bash
ssh root@10.0.0.4
/opt/mihomo/update-mihomo.sh
```

### 验证部署
```bash
bash scripts/verify-deployment.sh
```

### 故障诊断
```bash
bash scripts/diagnose.sh
```

### 命令速查
查看 [CHEATSHEET.md](CHEATSHEET.md)

---

## 文档

- [快速开始](QUICKSTART.md) - 详细部署指南
- [命令速查](CHEATSHEET.md) - 常用命令
- [完整配置](docs/CONFIG.md) - 高级配置
- [RouterOS](docs/ROUTEROS.md) - 路由器配置

---

## 常见问题

**Q: 需要什么硬件？**
- Proxmox VE 服务器
- MikroTik RouterOS 路由器
- 机场订阅

**Q: 部署需要多久？**
- 自动部署：15-20 分钟（含系统安装）
- 主要时间用于系统安装

**Q: 服务挂了会断网吗？**
- 不会，已配置容错机制

---

## 贡献

- 🐛 [报告问题](https://github.com/WinsPan/home-net/issues)
- 💡 [功能建议](https://github.com/WinsPan/home-net/issues)
- 🔧 贡献代码：Fork → PR

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

## 致谢

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)
- [AdguardTeam/AdGuardHome](https://github.com/AdguardTeam/AdGuardHome)
- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)
- [privacy-protection-tools/anti-AD](https://github.com/privacy-protection-tools/anti-AD)

---

**项目地址：** https://github.com/WinsPan/home-net
