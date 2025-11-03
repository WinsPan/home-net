# 更新日志

## [7.0.0] - 2025-11-03

### 🚀 完全精简重构

**核心改进：**
- ✅ 只保留一个部署脚本 `deploy.sh`
- ✅ 使用 cloud-init 完全自动部署
- ✅ 删除所有冗余文档和脚本
- ✅ README 超级简洁

**删除文件：**
- ❌ deploy-auto.sh（功能合并到 deploy.sh）
- ❌ QUICKSTART.md
- ❌ CHEATSHEET.md
- ❌ docs/ROUTEROS.md
- ❌ scripts/diagnose.sh
- ❌ scripts/verify-deployment.sh

**保留文件：**
- ✅ deploy.sh（完全自动）
- ✅ test-deployment.sh（测试）
- ✅ README.md（超级简洁）
- ✅ docs/CONFIG.md（完整配置）
- ✅ scripts/install-*.sh（安装脚本）
- ✅ scripts/update-mihomo.sh（更新脚本）

**部署方式：**
```bash
curl -fsSL https://raw.../deploy.sh | bash
```

**项目结构：**
```
boomdns/
├── deploy.sh              # 一键部署
├── test-deployment.sh     # 测试验证
├── README.md              # 简洁说明
├── CHANGELOG.md           # 更新日志
├── docs/CONFIG.md         # 完整配置
└── scripts/               # 安装和更新脚本
    ├── install-mihomo-vm.sh
    ├── install-adguardhome-vm.sh
    └── update-mihomo.sh
```

**用户体验：**
- 文档数量：从 8 个 → 3 个
- 脚本数量：从 7 个 → 4 个
- 部署命令：1 条
- 学习时间：< 3 分钟
