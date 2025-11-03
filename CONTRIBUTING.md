# 贡献指南

感谢您对 BoomDNS 项目的关注！我们欢迎所有形式的贡献。

## 🤝 如何贡献

### 报告 Bug

如果您发现了 bug，请：

1. 检查 [Issues](https://github.com/WinsPan/home-net/issues) 是否已有人报告
2. 如果没有，创建新的 Issue，包含：
   - Bug 的详细描述
   - 复现步骤
   - 预期行为
   - 实际行为
   - 环境信息（Proxmox 版本、系统架构等）
   - 相关日志

### 提出新功能

我们欢迎功能建议！请：

1. 在 Issues 中创建 Feature Request
2. 详细描述您的想法
3. 说明这个功能的使用场景
4. 如果可能，提供实现思路

### 提交代码

#### 开发环境准备

```bash
# 克隆仓库
git clone https://github.com/WinsPan/home-net.git
cd home-net

# 创建新分支
git checkout -b feature/your-feature-name
```

#### 代码规范

**Shell 脚本规范：**

1. 使用 `#!/usr/bin/env bash` 作为 shebang
2. 添加适当的注释
3. 使用有意义的变量名
4. 错误处理：使用 `set -e` 或适当的错误检查
5. 函数命名：使用小写字母和下划线
6. 缩进：使用 4 个空格

**示例：**

```bash
#!/usr/bin/env bash

# 脚本描述
# Author: Your Name
# License: MIT

set -e

# 全局变量
SCRIPT_VERSION="1.0.0"

# 函数定义
function show_info() {
    echo "[INFO] $1"
}

function main() {
    show_info "Starting script..."
    # 主逻辑
}

# 执行主函数
main
```

#### 提交信息规范

使用清晰的提交信息：

```
类型: 简短描述

详细描述（可选）

Footer（可选）
```

**类型：**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例：**

```
feat: 添加自动更新功能

- 实现版本检查
- 支持自动下载更新
- 添加备份恢复机制

Closes #123
```

#### Pull Request 流程

1. **确保代码质量**
   - 代码符合规范
   - 所有脚本都有执行权限
   - 测试通过

2. **创建 Pull Request**
   - 清晰的标题和描述
   - 关联相关 Issue
   - 说明改动内容

3. **代码审查**
   - 响应审查意见
   - 及时更新代码

4. **合并**
   - 审查通过后会被合并
   - 感谢您的贡献！

### 改进文档

文档同样重要！您可以：

- 修正错别字
- 改进表述
- 添加示例
- 翻译文档

## 🧪 测试

在提交代码前，请确保：

1. **基本测试**
```bash
# 测试脚本语法
bash -n scripts/create-mihomo-lxc.sh

# 测试权限
ls -l scripts/*.sh
```

2. **功能测试**
   - 在 Proxmox 测试环境中运行
   - 验证所有功能正常
   - 检查日志无错误

3. **不同架构测试**
   - x86_64
   - ARM64（如果可能）

## 📝 文档更新

如果您的改动涉及：

- 新功能 → 更新 README.md 和 USAGE.md
- 配置变更 → 更新 config-examples.yaml
- 使用方法变更 → 更新 QUICKSTART.md

## 🎯 优先级

我们特别欢迎以下方面的贡献：

1. **Bug 修复** - 最高优先级
2. **文档改进** - 帮助更多用户
3. **性能优化** - 提升用户体验
4. **新功能** - 扩展项目能力
5. **测试** - 提高代码质量

## 💡 开发建议

### 测试环境

建议准备：
- Proxmox VE 8.x 测试环境
- 至少 2GB 可用内存
- 10GB 可用存储

### 调试技巧

```bash
# 查看详细日志
journalctl -u mihomo -f

# 测试配置文件
mihomo -d /etc/mihomo -t

# 检查端口监听
ss -tuln | grep -E '7890|9090'
```

## 🔍 代码审查清单

提交前请检查：

- [ ] 代码符合规范
- [ ] 添加了必要的注释
- [ ] 错误处理完善
- [ ] 变量命名清晰
- [ ] 函数单一职责
- [ ] 脚本有执行权限
- [ ] 文档已更新
- [ ] 测试通过

## 📧 联系方式

如有问题，可以：

- 创建 Issue
- 参与 Discussions
- 发送邮件至：[您的邮箱]

## 📜 许可证

贡献的代码将采用项目的 MIT 许可证。

## 🙏 致谢

感谢每一位贡献者！您的贡献让这个项目变得更好！

---

**再次感谢您的贡献！** ❤️

