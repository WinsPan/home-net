# 完全重构计划

## 目标

创建一个**专业级**的 Proxmox VM 部署和管理系统

## 参考

- https://github.com/community-scripts/ProxmoxVE/blob/main/vm/debian-13-vm.sh

## 新架构

### 1. VM 创建模块 ✨

**create-vm.sh**
- 参考 community-scripts 的最佳实践
- 支持交互式配置（whiptail）
- Cloud-init 完整支持
- 自定义 IP、CPU、内存、磁盘
- SSH 自动配置
- 自动验证和错误处理

**功能：**
- ✅ 自动获取有效 VMID
- ✅ 存储池选择
- ✅ 网络配置（静态 IP）
- ✅ Cloud-init 集成
- ✅ SSH 密钥注入
- ✅ 自动启动选项

### 2. mihomo 管理模块 🚀

**mihomo/install.sh** - 快速部署
- 一键安装
- 自动配置

**mihomo/manage.sh** - 完整管理
- 修改订阅地址
- 切换配置模式
- 透明代理配置
- 节点测试
- 日志查看
- 服务管理

**功能：**
```bash
mihomo-manage.sh menu
├── 1) 查看状态
├── 2) 修改订阅
├── 3) 更新订阅
├── 4) 切换配置模式
├── 5) 配置透明代理
├── 6) 测试节点
├── 7) 查看日志
└── 8) 重启服务
```

### 3. AdGuard Home 模块 🛡️

**adguardhome/install.sh** - 快速部署
- 自动下载安装
- 基础配置
- 规则导入

**功能：**
- ✅ 一键安装
- ✅ 自动配置端口
- ✅ 推荐规则自动添加

### 4. RouterOS 完整配置 🌐

**routeros/generate-config.sh**

**功能：**
- ✅ 完整的分流配置
- ✅ 广告过滤配置
- ✅ 透明代理支持
- ✅ 健康检查
- ✅ 容错机制

## 实现步骤

1. ✅ 创建新目录结构
2. ✅ 实现 VM 创建脚本
3. ✅ 实现 mihomo 管理脚本
4. ✅ 实现 AdGuard 快速部署
5. ✅ 实现 RouterOS 配置生成
6. ✅ 创建主部署脚本
7. ✅ 删除旧文件
8. ✅ 更新文档

## 用户体验

**之前：**
```bash
bash deploy.sh
# 等待完成
```

**重构后：**
```bash
# 1. 创建 VM（交互式，专业）
bash vm/create-vm.sh

# 2. 安装 mihomo
bash services/mihomo/install.sh

# 3. 管理 mihomo（完整功能）
bash services/mihomo/manage.sh

# 4. 安装 AdGuard
bash services/adguardhome/install.sh

# 5. 生成 RouterOS 配置
bash routeros/generate-config.sh

# 或使用主脚本一键完成
bash setup.sh
```

## 技术亮点

1. **参考最佳实践** - 基于 community-scripts
2. **交互式体验** - whiptail 界面
3. **模块化设计** - 独立可维护
4. **完整功能** - 从部署到管理
5. **专业错误处理** - 详细提示

开始实现！
