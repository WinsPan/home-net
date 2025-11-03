# 文档索引 - 如何选择合适的文档

根据您的需求和场景，快速找到正确的文档。

## 📍 您的网络环境

如果您的网络规划是：
- **RouterOS**: 10.0.0.2
- **mihomo VM**: 10.0.0.4  
- **AdGuard Home VM**: 10.0.0.5

**↓ 请使用以下文档 ↓**

## 🎯 推荐阅读路径（按顺序）

### 第一步：快速了解
📖 **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** ⭐⭐⭐
- **适用场景**: 10.0.0.x 网段 + RouterOS + Debian VM
- **内容**: 三步快速部署、验证清单、常用命令
- **阅读时间**: 5-10 分钟
- **推荐指数**: ⭐⭐⭐⭐⭐

### 第二步：详细部署
📖 **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** ⭐⭐⭐
- **适用场景**: Debian 虚拟机完整部署
- **内容**: 从创建VM到配置完成的详细步骤
- **阅读时间**: 30-45 分钟
- **推荐指数**: ⭐⭐⭐⭐⭐

### 第三步：RouterOS 配置
📖 **[ROUTEROS-CONFIG.md](ROUTEROS-CONFIG.md)** ⭐⭐
- **适用场景**: RouterOS 主路由配置
- **内容**: DNS劫持、防火墙规则、高级配置
- **阅读时间**: 20-30 分钟
- **推荐指数**: ⭐⭐⭐⭐

### 第四步：规则配置（可选）
📖 **[adguardhome-rules.md](adguardhome-rules.md)** ⭐
- **适用场景**: 配置广告过滤规则
- **内容**: 规则来源、配置方法、优化建议
- **阅读时间**: 15-20 分钟
- **推荐指数**: ⭐⭐⭐⭐

---

## 📚 其他文档（参考用）

### 组合方案
📖 **[INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md)**
- **适用场景**: 了解 mihomo + AdGuard Home 组合原理
- **内容**: 三种架构方案、优化配置
- **用途**: 参考，已整合到 DEPLOYMENT-GUIDE

### LXC 容器方式
📖 **[QUICKSTART.md](QUICKSTART.md)**
- **适用场景**: 使用 LXC 容器（非虚拟机）
- **内容**: LXC 自动部署流程
- **注意**: 不适用于您的虚拟机场景

### mihomo 配置详解
📖 **[USAGE.md](USAGE.md)**
- **适用场景**: 深入了解 mihomo 配置
- **内容**: 配置文件详解、高级功能
- **用途**: 参考文档

### 配置示例
📖 **[config-examples.yaml](config-examples.yaml)**
- **适用场景**: mihomo 配置参考
- **内容**: 各种场景的配置示例
- **用途**: 复制粘贴配置

---

## 🚀 部署脚本选择

### 虚拟机部署（您的方案）⭐

在 **Debian 12 虚拟机**中执行：

```bash
# mihomo 安装
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh)

# AdGuard Home 安装
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh)
```

### LXC 容器部署（另一种方案）

在 **Proxmox 主机**上执行：

```bash
# mihomo LXC
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)

# AdGuard Home LXC
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-adguardhome-lxc.sh)
```

---

## 🎓 学习路径建议

### 新手路径（零基础）

1. **阅读** [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - 了解整体流程
2. **跟随** [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - 一步步操作
3. **配置** RouterOS - 参考 QUICK-REFERENCE 中的命令
4. **验证** - 使用验证清单检查
5. **优化** - 添加广告过滤规则（可选）

**预计时间**: 2-3 小时

### 进阶路径（有基础）

1. **快速部署** - 使用 VM 安装脚本
2. **参考配置** - QUICK-REFERENCE 中的 RouterOS 命令
3. **深入学习** - ROUTEROS-CONFIG 高级功能
4. **性能优化** - DEPLOYMENT-GUIDE 的优化章节

**预计时间**: 1-2 小时

---

## 🆘 遇到问题？

### 按问题类型查找

| 问题类型 | 查看文档 | 章节 |
|---------|---------|------|
| 虚拟机创建失败 | DEPLOYMENT-GUIDE.md | 第一步、第二步 |
| IP 配置不正确 | QUICK-REFERENCE.md | 第一步配置静态IP |
| RouterOS 配置 | ROUTEROS-CONFIG.md | 基础配置 / 故障排查 |
| DNS 不解析 | QUICK-REFERENCE.md | 常见问题快速解决 |
| 广告拦截不生效 | adguardhome-rules.md | 常见问题 |
| 代理不工作 | QUICK-REFERENCE.md | 问题：代理不工作 |
| 服务启动失败 | DEPLOYMENT-GUIDE.md | 故障排查 |

### 快速命令参考

所有常用命令都在：**[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** 的"常用命令"章节

---

## 📊 文档对比表

| 文档 | 适用场景 | 网段 | 部署方式 | 详细程度 | 推荐度 |
|------|---------|------|----------|---------|--------|
| **QUICK-REFERENCE** | 您的环境 | 10.0.0.x | VM | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **DEPLOYMENT-GUIDE** | VM详细部署 | 10.0.0.x | VM | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **ROUTEROS-CONFIG** | ROS配置 | 10.0.0.x | - | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **INTEGRATION-GUIDE** | 组合原理 | 10.0.0.x | 通用 | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **adguardhome-rules** | 规则配置 | - | - | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| QUICKSTART | LXC方式 | 任意 | LXC | ⭐⭐ | ⭐⭐ |
| USAGE | mihomo配置 | 任意 | 通用 | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| config-examples | 配置参考 | - | - | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 💡 提示

1. **从简单开始**: 先看 QUICK-REFERENCE.md
2. **遇到问题再深入**: 需要时查看 DEPLOYMENT-GUIDE.md
3. **保存快速参考**: QUICK-REFERENCE.md 可以打印或收藏
4. **记录修改**: 在部署过程中记录您的配置
5. **定期备份**: 配置完成后备份所有配置文件

---

## 🎯 快速跳转

- **立即开始**: [QUICK-REFERENCE.md](QUICK-REFERENCE.md) ⭐
- **详细步骤**: [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) ⭐
- **ROS配置**: [ROUTEROS-CONFIG.md](ROUTEROS-CONFIG.md)
- **返回主页**: [README.md](../README.md)

---

**祝您部署顺利！** 🚀✨

