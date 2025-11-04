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

### 2. 安装 sing-box（10.0.0.3）

```bash
ssh root@10.0.0.3
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh | bash
```

**要求：**
- 订阅必须是 **sing-box 格式**
- Clash 订阅需要先通过 Sub-Store 转换

**一键安装：**
```bash
SUB_URL="你的sing-box订阅地址" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-singbox.sh)"
```

---

### 2.5 （可选）部署 Sub-Store 订阅转换

**如果你的订阅是 Clash 格式，需要先部署 Sub-Store 进行转换**

```bash
ssh root@10.0.0.3
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-substore-docker.sh | bash
```

**Sub-Store 功能：**
- ✅ Web UI 管理：`http://10.0.0.3:3001`
- ✅ 转换 Clash → sing-box
- ✅ 多订阅合并
- ✅ 高级过滤规则
- ✅ Docker 部署，轻量级

**使用流程：**
1. 访问 `http://10.0.0.3:3001`
2. 添加 Clash 订阅源
3. 创建订阅集合，选择输出格式：**sing-box**
4. 复制生成的订阅链接
5. 使用该链接安装 sing-box

### 3. 安装AdGuard Home（10.0.0.4）

```bash
ssh root@10.0.0.4
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/install-adguardhome.sh | bash
```

**安装后配置：**
1. 访问：`http://10.0.0.4:3000`
2. 完成初始化向导
3. 参考详细配置：**[ADGUARDHOME.md](ADGUARDHOME.md)** 📖

---

## 📖 详细文档

**主要文档：**
- **[DEPLOY.md](DEPLOY.md)** - 完整部署指南（RouterOS配置、故障转移等）
- **[ADGUARDHOME.md](ADGUARDHOME.md)** - AdGuard Home 详细配置手册

**内容包括：**
- IP地址规划
- 详细部署步骤
- DNS 服务器配置
- 过滤规则推荐
- RouterOS集成
- 性能优化
- 故障排查

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
