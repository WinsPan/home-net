# 更新日志

本文档记录了 BoomDNS 项目的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### 计划功能
- Web UI 管理界面
- 一键订阅导入
- 自动配置优化

## [1.1.0] - 2024-11-03

### 新增
- ✨ 虚拟机部署方案（install-mihomo-vm.sh, install-adguardhome-vm.sh）
- ✨ 针对 10.0.0.x 网段的完整部署指南（DEPLOYMENT-GUIDE.md）
- ✨ 快速参考手册（QUICK-REFERENCE.md）
- ✨ RouterOS (MikroTik) 详细配置指南（ROUTEROS-CONFIG.md）
- ✨ mihomo + AdGuard Home 组合方案指南（INTEGRATION-GUIDE.md）
- ✨ AdGuard Home 广告过滤功能和规则配置
- ✨ 支持两种部署方式：LXC 容器和完整虚拟机

### 改进
- 📚 完善文档体系，针对不同场景提供专门指南
- 🎯 针对实际网络环境（ROS + PVE VM）优化配置示例
- 🔧 提供完整的故障排查和性能优化建议

### 删除
- 🗑️ 移除冗余的 CT 脚本和安装脚本
- 🗑️ 清理不再使用的目录结构

## [1.0.0] - 2024-11-03

### 新增
- 🎉 首次发布
- ✨ 自动创建 Debian 12 LXC 容器
- ✨ 自动安装最新版 mihomo
- ✨ 交互式配置向导
- ✨ 支持 DHCP 和静态 IP 配置
- ✨ 自动配置 systemd 服务
- ✨ 多架构支持（x86_64、ARM64、ARMv7）
- ✨ 预配置 DNS 和代理设置
- ✨ Web 控制面板支持
- ✨ 更新脚本
- 📚 完整的文档体系
  - README.md - 项目说明
  - QUICKSTART.md - 快速入门指南
  - USAGE.md - 详细使用文档
  - config-examples.yaml - 配置示例
  - CONTRIBUTING.md - 贡献指南

### 脚本
- `scripts/create-mihomo-lxc.sh` - 主部署脚本
- `scripts/install/mihomo-install.sh` - mihomo 安装脚本
- `scripts/ct/mihomo.sh` - CT 容器脚本
- `scripts/misc/update-mihomo.sh` - 更新脚本

### 文档
- 中文文档完整支持
- 详细的安装步骤说明
- 故障排查指南
- 配置示例和最佳实践

### 特性
- 🚀 一键部署，5 分钟完成安装
- 🔧 开箱即用的默认配置
- 📊 完善的日志和监控
- 🔄 自动更新支持
- 🛡️ 安全的容器隔离
- 💾 配置备份和恢复

## [0.1.0] - 2024-11-02

### 新增
- 项目初始化
- 基础架构搭建
- 核心功能开发

---

## 版本说明

### 版本号格式：主版本号.次版本号.修订号

- **主版本号**：重大变更或不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 变更类型

- `新增` - 新功能
- `变更` - 现有功能的变更
- `废弃` - 即将移除的功能
- `移除` - 已移除的功能
- `修复` - Bug 修复
- `安全` - 安全相关的修复

---

[未发布]: https://github.com/WinsPan/home-net/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/WinsPan/home-net/releases/tag/v1.0.0
[0.1.0]: https://github.com/WinsPan/home-net/releases/tag/v0.1.0

