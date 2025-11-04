# 快速开始

5 分钟完成部署！

---

## 前提条件

- Proxmox VE 8.x 或 9.0
- root 权限
- 网络连接

---

## 一键部署

### 方式 1：在线安装（推荐）⭐

```bash
# 在 Proxmox 节点运行（需要 root 权限）
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install.sh | bash
```

**安装后使用：**
```bash
boomdns setup     # 开始部署
```

### 方式 2：Git 克隆

```bash
git clone https://github.com/WinsPan/home-net.git
cd home-net
bash setup.sh
```

按照提示完成配置即可！

---

## 部署流程

### 1. 创建 VM (2 分钟)
- 交互式选择配置
- 自动创建 mihomo 和 AdGuard Home VM
- Cloud-init 自动配置

### 2. 安装服务 (2 分钟)
- 自动安装 mihomo
- 自动安装 AdGuard Home
- 自动配置服务

### 3. 生成配置 (1 分钟)
- 自动生成 RouterOS 配置
- 包含分流和广告过滤

---

## 完成后

### 访问服务

```
mihomo 面板:   http://10.0.0.3:9090
AdGuard Home:  http://10.0.0.4:3000
```

### 管理 mihomo

```bash
bash services/mihomo/manage.sh
```

功能：
- 修改订阅地址
- 更新订阅
- 配置透明代理
- 测试节点
- 查看日志

### 应用 RouterOS 配置

1. 复制生成的 `routeros-config.rsc`
2. 在 RouterOS 终端执行

---

## 测试

```bash
# 测试代理
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 测试 DNS
nslookup google.com 10.0.0.4
```

---

## 常见问题

**Q: 部署失败？**
- 检查网络连接
- 查看日志：`journalctl -u mihomo -f`

**Q: 如何更换订阅？**
```bash
bash services/mihomo/manage.sh
# 选择 "2) 修改订阅"
```

**Q: 如何配置透明代理？**
```bash
bash services/mihomo/manage.sh
# 选择 "5) 配置透明代理"
```

---

完成！更多帮助请查看 [README.md](README.md) 和 [docs/CONFIG.md](docs/CONFIG.md)

