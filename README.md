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

```bash
ssh root@10.0.0.3
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash
```

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
