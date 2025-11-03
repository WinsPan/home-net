# BoomDNS

智能分流 + 广告过滤 - 家庭网络解决方案

---

## 快速部署

```bash
# 方式 1：下载后运行（推荐）
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh
bash deploy.sh

# 方式 2：直接运行
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh | bash
```

**10-15 分钟自动完成：**
- ✅ 自动下载 cloud-init 镜像
- ✅ 自动创建 VM
- ✅ 自动配置网络
- ✅ 自动安装 mihomo + AdGuard Home
- ✅ 自动生成 RouterOS 配置

---

## 测试验证

```bash
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/test-deployment.sh | bash
```

---

## 服务访问

```
mihomo 面板:    http://10.0.0.4:9090
AdGuard Home:   http://10.0.0.5:3000
```

---

## 配置代理

### 方式 1：手动代理（推荐）

在客户端设置代理：
- 代理地址: `10.0.0.4`
- 代理端口: `7890`

### 方式 2：透明代理（高级）

查看 [docs/CONFIG.md](docs/CONFIG.md#透明代理配置)

---

## IP 规划

```
RouterOS:      10.0.0.2
mihomo:        10.0.0.4
AdGuard Home:  10.0.0.5
```

---

## 维护

```bash
# 更新 mihomo
ssh root@10.0.0.4
bash /root/scripts/update-mihomo.sh

# 查看日志
journalctl -u mihomo -f
journalctl -u AdGuardHome -f
```

---

## 文档

- [完整配置](docs/CONFIG.md) - mihomo、AdGuard、RouterOS 详细配置
- [更新日志](CHANGELOG.md)

---

## License

MIT
