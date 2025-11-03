# 贡献指南

感谢你考虑为 BoomDNS 做出贡献！

---

## 如何贡献

### 报告 Bug

提交 Bug 前请：

1. 检查是否已有相同 Issue
2. 确保使用最新版本
3. 提供详细复现步骤

**Bug 报告模板：**
```
环境：
- Proxmox VE: x.x
- Debian: 12
- mihomo: x.x.x

问题描述：
[详细描述问题]

复现步骤：
1. ...
2. ...

预期行为：
[应该发生什么]

实际行为：
[实际发生了什么]

日志：
[相关日志内容]
```

### 提出新功能

有好想法？

1. 先创建 Issue 讨论
2. 说明使用场景
3. 提供实现思路（如果有）

### 提交代码

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/xxx`
3. 提交更改：`git commit -m "feat: xxx"`
4. 推送分支：`git push origin feature/xxx`
5. 创建 Pull Request

---

## 代码规范

### Shell 脚本

```bash
#!/bin/bash

# 使用 set -e
set -e

# 清晰的变量命名
MIHOMO_VERSION="1.18.0"
INSTALL_DIR="/opt/mihomo"

# 函数注释
function install_mihomo() {
    # 安装 mihomo
    echo "Installing..."
}
```

### 文档

- 使用清晰的标题层级
- 提供具体示例
- 代码块标注语言
- 保持格式一致

---

## Commit 规范

使用语义化提交：

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档更新
- `refactor:` 代码重构
- `perf:` 性能优化
- `test:` 测试相关
- `chore:` 构建/工具

**示例：**
```
feat: 添加智能配置选项

- 支持智能/基础配置选择
- 自动生成 API 密钥
- 交互式配置流程
```

---

## 开发设置

### 本地测试

1. 准备 Proxmox VE 环境
2. 创建测试 VM
3. 运行部署脚本测试

### 文档测试

所有命令和配置都必须经过实际测试。

---

## 审核流程

1. 代码审查
2. 测试验证
3. 文档检查
4. 合并到主分支

---

## 许可

提交代码即表示你同意使用 MIT License。

---

## 联系

- Issues: https://github.com/WinsPan/home-net/issues
- Pull Requests: https://github.com/WinsPan/home-net/pulls

---

再次感谢你的贡献！🎉
