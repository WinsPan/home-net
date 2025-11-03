# 更新日志

## [3.0.0] - 2025-11-03

### 🎉 完全重构

项目完全重构，精简为最核心功能。

### ✨ 新增

- **统一配置文档** - `docs/CONFIG.md` 整合所有配置
- **智能安装脚本** - 支持智能/基础配置选择
- **更新脚本** - 一键更新 mihomo
- **精简 README** - 清晰的快速开始指南

### 🗑️ 删除

- 冗余配置文档（COMPLETE-CONFIG.md, SMART-CONFIG.md）
- 重复部署文档（DEPLOYMENT.md）
- 配置示例文件（config-examples.yaml）
- 独立智能配置脚本

### 📝 文档

- **docs/CONFIG.md** - 唯一完整配置文档
  - mihomo 智能配置
  - AdGuard Home 配置
  - RouterOS 配置
  - 故障排查

- **docs/ROUTEROS.md** - 精简的 RouterOS 配置
  - 快速配置
  - 容错机制
  - 性能优化

### 🚀 脚本

- **scripts/install-mihomo-vm.sh** - 统一安装脚本
  - 💡 智能配置选项
  - 📝 基础配置选项
  - 自动生成 API 密钥
  - 交互式配置

- **scripts/install-adguardhome-vm.sh** - AdGuard Home 安装
- **scripts/update-mihomo.sh** - mihomo 更新工具

### 🎯 重构目标

- 删除 70% 冗余内容
- 文档从 5 个精简到 2 个
- 脚本从 4 个精简到 3 个
- 保留核心功能，极简易用

---

## [2.0.0] - 2025-11-03

### 新增

- Smart 策略支持
- 多机场订阅
- 动态规则更新
- Web 管理界面

### 改进

- 完善容错机制
- 优化性能

---

## [1.1.0] - 2025-11-02

### 新增

- VM 部署支持
- 针对 10.0.0.x 网段配置
- AdGuard Home 集成

---

## [1.0.0] - 2025-11-01

### 初始版本

- mihomo 自动部署
- AdGuard Home 广告过滤
- RouterOS 配置指南
