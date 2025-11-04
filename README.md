# BoomDNS

**专业级** Proxmox VM 部署和管理系统  
mihomo + AdGuard Home + RouterOS 完整解决方案

---

## ✨ 特性

- 🚀 **专业 VM 创建** - 基于 [community-scripts](https://github.com/community-scripts/ProxmoxVE) 最佳实践
- 🎯 **交互式配置** - 友好的配置界面
- ☁️ **Cloud-init 支持** - 自动化系统配置
- 🔧 **完整管理** - mihomo 订阅/配置/透明代理管理
- 🛡️ **广告过滤** - AdGuard Home 快速部署
- 🌐 **RouterOS 集成** - 自动生成完整配置

---

## 🚀 快速开始

### 方式 1：交互式部署（推荐）

```bash
# 在 Proxmox 节点运行
git clone https://github.com/WinsPan/home-net.git
cd home-net
bash setup.sh
```

### 方式 2：分步部署

```bash
# 1. 创建 VM
bash vm/create-vm.sh

# 2. 安装 mihomo
bash services/mihomo/install.sh

# 3. 管理 mihomo
bash services/mihomo/manage.sh

# 4. 安装 AdGuard Home
bash services/adguardhome/install.sh

# 5. 生成 RouterOS 配置
bash routeros/generate-config.sh
```

---

## 📁 项目结构

```
boomdns/
├── setup.sh                       # 主部署脚本（交互式菜单）
├── vm/
│   └── create-vm.sh              # VM 创建（Cloud-init）
├── services/
│   ├── mihomo/
│   │   ├── install.sh            # mihomo 安装
│   │   └── manage.sh             # mihomo 管理（订阅/配置/透明代理）
│   └── adguardhome/
│       └── install.sh            # AdGuard Home 安装
├── routeros/
│   └── generate-config.sh        # RouterOS 配置生成
└── docs/
    └── CONFIG.md                 # 详细配置文档
```

---

## 🎯 功能亮点

### VM 创建
- ✅ 自动获取有效 VMID
- ✅ 自定义 CPU/内存/磁盘
- ✅ Cloud-init 自动配置
- ✅ SSH 密钥注入
- ✅ 静态 IP 配置
- ✅ 开机自启动

### mihomo 管理
- ✅ 一键安装
- ✅ 订阅管理（修改/更新）
- ✅ 配置切换
- ✅ 透明代理配置
- ✅ 节点测试
- ✅ 日志查看
- ✅ 服务管理

### AdGuard Home
- ✅ 快速部署
- ✅ 自动配置
- ✅ 推荐规则

### RouterOS
- ✅ 完整分流配置
- ✅ 广告过滤配置
- ✅ 透明代理支持
- ✅ 健康检查机制
- ✅ 故障自动切换

---

## 📊 默认 IP 规划

```
RouterOS:      10.0.0.2
mihomo:        10.0.0.3
AdGuard Home:  10.0.0.4
DHCP 池:       10.0.0.100-200
```

---

## 🔧 使用示例

### 创建 VM
```bash
bash vm/create-vm.sh

# 交互式配置：
# - VM 名称
# - VMID
# - CPU/内存/磁盘
# - 网络配置
# - SSH 密钥
```

### mihomo 管理菜单
```bash
bash services/mihomo/manage.sh

菜单选项：
  1) 查看状态
  2) 修改订阅
  3) 更新订阅
  4) 配置透明代理
  5) 测试节点
  6) 查看日志
  7) 重启服务
  8) 查看配置
```

### RouterOS 配置
```bash
bash routeros/generate-config.sh

# 生成 routeros-config.rsc
# 在 RouterOS 执行: /import file=routeros-config.rsc
```

---

## 📚 文档

详细配置和说明: [docs/CONFIG.md](docs/CONFIG.md)

---

## 🎓 技术参考

- Proxmox VE: https://www.proxmox.com/
- mihomo: https://github.com/MetaCubeX/mihomo
- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome
- Community Scripts: https://github.com/community-scripts/ProxmoxVE

---

## 🆕 更新日志

### v8.0.0 - 完全重构
- 全新架构设计
- 基于 community-scripts 最佳实践
- 模块化设计
- 完整的管理功能
- 交互式部署体验

[查看完整更新日志](CHANGELOG.md)

---

## 📝 License

MIT License

---

**更专业、更强大、更易用！** 🚀
