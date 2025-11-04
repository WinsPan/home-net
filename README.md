# home-net

> sing-box + AdGuard Home 家庭网络方案

---

## 📦 三个脚本

| 脚本 | 功能 | 在哪运行 |
|------|------|---------|
| `create-vm.sh` | 创建VM | PVE节点 |
| `install-singbox.sh` | 安装sing-box | sing-box VM |
| `install-adguardhome.sh` | 安装AdGuard Home | AdGuard Home VM |

---

## 🚀 快速开始

### 1. 创建VM（PVE节点）

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/create-vm.sh -o create-vm.sh

# 创建sing-box VM
bash create-vm.sh
# VM名称: sing-box, VMID: 101, IP: 10.0.0.3/24

# 创建AdGuard Home VM
bash create-vm.sh
# VM名称: adguardhome, VMID: 102, IP: 10.0.0.4/24
```

### 2. 安装sing-box（10.0.0.3）

#### 🎯 方案A：基础版本（快速）

适合：sing-box 订阅或标准 Clash 订阅

```bash
ssh root@10.0.0.3

# 交互式安装
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash

# 或一键安装
SUB_URL="你的订阅地址" SUB_TYPE="2" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh)"

# SUB_TYPE=1: sing-box订阅
# SUB_TYPE=2: Clash订阅（自动转换）
```

#### 🚀 方案B：Sub-Store 版本（推荐）

适合：复杂订阅、多订阅合并、高级规则

特性：
- ✅ Web UI 管理订阅
- ✅ 支持更多订阅格式
- ✅ 强大的过滤和规则
- ✅ 多订阅合并

```bash
ssh root@10.0.0.3
SUB_URL="你的订阅地址" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox-v2.sh)"
```

安装后访问：`http://10.0.0.3:3001` 进入 Sub-Store Web UI

> 💡 **推荐使用方案B**，转换更可靠，管理更方便

### 3. 安装AdGuard Home（10.0.0.4）

```bash
ssh root@10.0.0.4
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh | bash
```

访问：http://10.0.0.4:3000 完成初始化

---

## 📖 详细文档

查看完整配置说明：**[DEPLOY.md](DEPLOY.md)**

内容包括：
- IP地址规划
- 详细部署步骤
- AdGuard Home配置
- RouterOS集成
- 测试验证
- 服务管理
- 常见问题

---

## 📊 IP规划

```
RouterOS:  10.0.0.2  (主路由)
sing-box:  10.0.0.3  (代理)
AdGuard:   10.0.0.4  (DNS)
```

---

## 🔧 服务管理

```bash
# sing-box
ssh root@10.0.0.3
systemctl status sing-box
journalctl -u sing-box -f

# AdGuard Home
ssh root@10.0.0.4
systemctl status AdGuardHome
journalctl -u AdGuardHome -f
```

---

## 🧪 测试

```bash
# 测试代理
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 测试DNS
nslookup google.com 10.0.0.4
```

---

## 📄 许可证

MIT

---

**完整文档：[DEPLOY.md](DEPLOY.md)**
