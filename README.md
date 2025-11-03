# BoomDNS

mihomo + AdGuard Home 智能分流 + 广告过滤

---

## 快速部署

```bash
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh
bash deploy.sh
```

⏱️ **10-15 分钟自动完成**

---

## 服务地址

```
mihomo:       http://10.0.0.3:9090
AdGuard Home: http://10.0.0.4:3000
```

---

## 代理配置

在客户端设置代理：
- 地址: `10.0.0.3`
- 端口: `7890`

---

## IP 规划

```
RouterOS:      10.0.0.2
mihomo:        10.0.0.3
AdGuard Home:  10.0.0.4
```

---

## 测试

```bash
# 测试代理
curl -x http://10.0.0.3:7890 https://www.google.com -I

# 自动测试
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/test-deployment.sh | bash
```

---

## 文档

详细配置: [docs/CONFIG.md](docs/CONFIG.md)

---

## License

MIT
