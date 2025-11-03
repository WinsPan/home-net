# BoomDNS

智能分流 + 广告过滤的完整家庭网络解决方案

## 快速了解

这个项目帮你在 Proxmox VE 上快速部署：

- **mihomo** (10.0.0.4) - 智能代理，实现自动分流
- **AdGuard Home** (10.0.0.5) - DNS 广告过滤
- **RouterOS** (10.0.0.2) - 网关配置

## 网络架构

```
设备 → RouterOS (10.0.0.2) → mihomo (10.0.0.4) → AdGuard Home (10.0.0.5) → 互联网
           ↓                      ↓                      ↓
       DNS劫持               智能分流              广告过滤
```

## 快速开始

### 1. 创建 VM

在 Proxmox VE 中创建两台 Debian 12 虚拟机：

```bash
# VM 100: mihomo (10.0.0.4)
# VM 101: AdGuard Home (10.0.0.5)
```

### 2. 安装服务

```bash
# 在 mihomo VM 上
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-mihomo-vm.sh | bash

# 在 AdGuard Home VM 上
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/install-adguardhome-vm.sh | bash
```

### 3. 配置 RouterOS

```bash
# 设置 DNS
/ip dns set servers=10.0.0.5

# 启用 DNS 劫持
/ip firewall nat add chain=dstnat protocol=udp dst-port=53 \
    action=dst-nat to-addresses=10.0.0.5
```

完成！🎉

## 文档

- **[完整配置方案](docs/COMPLETE-CONFIG.md)** - ⭐ 分流+去广告+容错完整配置
- **[部署指南](docs/DEPLOYMENT.md)** - 完整的部署步骤
- **[RouterOS 配置](docs/ROUTEROS.md)** - 路由器详细配置
- **[配置示例](docs/config-examples.yaml)** - mihomo 配置参考

## 特性

✅ **智能分流** - 国内外流量自动分流  
✅ **广告过滤** - 全网广告拦截  
✅ **一键部署** - 自动化安装脚本  
✅ **高性能** - 基于 Clash Meta 内核

## 技术栈

- Proxmox VE 8+
- Debian 12
- mihomo (Clash Meta)
- AdGuard Home
- RouterOS 7+

## 许可

MIT License

## 贡献

欢迎提交 Issue 和 PR！
