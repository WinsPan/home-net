# 贡献指南

感谢你考虑为 BoomDNS 做出贡献！

## 如何贡献

### 报告 Bug

在提交 Bug 之前：

1. 检查是否已有相同的 Issue
2. 确保使用的是最新版本
3. 提供详细的复现步骤

**Bug 报告应包含：**

- 系统环境（Proxmox VE 版本、Debian 版本）
- 网络配置（IP 地址、网络拓扑）
- 错误信息或日志
- 复现步骤

### 提出新功能

如果你有好的想法：

1. 先创建 Issue 讨论
2. 说明使用场景和理由
3. 提供实现思路（如果有）

### 提交代码

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m "feat: add something"`
4. 推送分支：`git push origin feature/your-feature`
5. 创建 Pull Request

### 代码规范

**Shell 脚本：**

```bash
#!/bin/bash
# 注释说明脚本功能

set -e  # 遇到错误立即退出

# 使用有意义的变量名
MIHOMO_VERSION="1.18.0"
INSTALL_DIR="/opt/mihomo"

# 函数注释
function install_mihomo() {
    echo "Installing mihomo..."
    # 实现代码
}
```

**文档：**

- 使用清晰的标题结构
- 提供具体的示例
- 代码块标注语言类型
- 保持格式一致

### Commit 规范

使用语义化提交信息：

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档更新
- `refactor:` 代码重构
- `test:` 测试相关
- `chore:` 构建/工具相关

**示例：**

```
feat: 添加 mihomo 自动更新功能

- 实现版本检测
- 添加自动下载和替换
- 保留配置文件
```

## 开发设置

### 本地测试

1. 准备 Proxmox VE 环境
2. 创建测试 VM
3. 运行部署脚本测试

### 文档测试

确保所有命令和配置都经过实际测试。

## 审核流程

1. 自动检查（如果有）
2. 代码审查
3. 测试验证
4. 合并到主分支

## 许可

提交代码即表示你同意使用 MIT License 授权。

## 联系

- GitHub Issues: [提交问题](https://github.com/WinsPan/home-net/issues)
- Pull Requests: [提交代码](https://github.com/WinsPan/home-net/pulls)

---

再次感谢你的贡献！ 🎉
