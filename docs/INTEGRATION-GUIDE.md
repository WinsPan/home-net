# mihomo + AdGuard Home 组合方案指南

> 💡 **推荐**: 如果您使用 10.0.0.x 网段，请优先查看：
> - [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - 基于您网络环境的快速参考 ⭐
> - [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - 完整部署步骤

本文档介绍如何将 mihomo 代理服务和 AdGuard Home 广告过滤组合使用，实现完美的网络体验。

## 🎯 方案架构

```
设备 → AdGuard Home (广告过滤) → mihomo (智能分流) → 互联网
         ↓                           ↓
    过滤广告/追踪              国内直连/国外代理
```

### 示例网络环境

本文档使用 **10.0.0.x** 网段作为示例：
- RouterOS: 10.0.0.2
- mihomo: 10.0.0.4
- AdGuard Home: 10.0.0.5

### 工作流程

1. **设备发起 DNS 请求** → AdGuard Home
2. **AdGuard Home 过滤广告** → 拦截广告域名
3. **合法请求转发** → mihomo DNS
4. **mihomo 智能分流** → 国内直连 / 国外代理
5. **返回结果** → 设备

## 🚀 快速部署

### 第一步：部署 mihomo

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)
```

**记录 mihomo IP**，例如：`10.0.0.4`

### 第二步：配置 mihomo

1. 进入 mihomo 容器：
```bash
pct enter <mihomo容器ID>
```

2. 编辑配置文件：
```bash
nano /etc/mihomo/config.yaml
```

3. 确保 DNS 配置正确：
```yaml
dns:
  enable: true
  listen: 0.0.0.0:53       # 监听所有网卡
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1
```

4. 重启 mihomo：
```bash
systemctl restart mihomo
exit
```

### 第三步：部署 AdGuard Home

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-adguardhome-lxc.sh)
```

**记录 AdGuard Home IP**，例如：`10.0.0.5`

### 第四步：配置 AdGuard Home

#### 1. 完成初始化

访问 `http://10.0.0.5:3000` 完成初始配置向导。

#### 2. 配置上游 DNS

进入：**设置 → DNS 设置 → 上游 DNS 服务器**

**重要：将 mihomo 的 DNS 作为上游**

```
# 主上游 DNS（mihomo）
10.0.0.4:53

# 备用 DNS（可选，防止 mihomo 故障）
223.5.5.5
119.29.29.29
```

**并行请求**：建议勾选

#### 3. 配置广告过滤规则

进入：**设置 → DNS 封锁清单**

**快速配置**（推荐）：

进入容器执行自动配置脚本：
```bash
pct enter <adguard容器ID>
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/misc/setup-adguard-rules.sh)
```

选择 **2) 进阶套餐**，然后按照提示手动添加规则到 AdGuard Home。

**详细配置**: 参考 [AdGuard Home 规则文档](adguardhome-rules.md)

### 第五步：配置设备 DNS

将设备或路由器的 DNS 设置为 AdGuard Home 的 IP：

```
主 DNS: 10.0.0.5
备用 DNS: 10.0.0.5
```

#### 路由器配置（推荐）

在路由器的 DHCP 设置中配置 DNS，这样网络中所有设备都会自动使用。

**RouterOS (MikroTik) 配置**：

```bash
# 设置路由器 DNS（指向 AdGuard Home）
/ip dns set servers=10.0.0.5

# 设置 DHCP 分发 DNS（让所有设备使用 AdGuard Home）
/ip dhcp-server network set [find] dns-server=10.0.0.5
```

**完整 RouterOS 配置指南**: 参考 [ROUTEROS-CONFIG.md](ROUTEROS-CONFIG.md)

**其他常见路由器配置位置**：
- OpenWrt: 网络 → 接口 → LAN → 编辑 → DHCP 服务器 → DNS 选项
- 爱快: 网络设置 → DHCP 设置 → DNS 服务器
- 梅林: 内部网络 → DHCP 服务器 → DNS 服务器
- 华硕/小米等: 局域网设置 → DHCP 设置

#### 单个设备配置

**Windows**：
```
控制面板 → 网络和共享中心 → 更改适配器设置 → 
右键网络连接 → 属性 → Internet 协议版本 4 → 属性 →
使用下面的 DNS 服务器地址
```

**macOS**：
```
系统偏好设置 → 网络 → 高级 → DNS → 添加
```

**iOS/Android**：
```
Wi-Fi 设置 → 配置 DNS → 手动 → 添加服务器
```

## ✅ 验证配置

### 1. 测试 DNS 解析

```bash
# 测试 AdGuard Home
nslookup google.com 10.0.0.5

# 测试 mihomo DNS
nslookup google.com 10.0.0.4
```

### 2. 测试广告拦截

访问：https://ads-blocker.com/zh-CN/testing/

应该看到大部分广告被拦截。

### 3. 测试智能分流

```bash
# 国内网站应该直连
curl -I https://baidu.com

# 国外网站应该走代理
curl -I https://google.com
```

### 4. 查看 AdGuard Home 统计

访问：`http://10.0.0.5:3000`

查看仪表板，应该能看到：
- 查询数量
- 已拦截查询
- 拦截率

## 🔧 高级配置

### 方案 A：AdGuard Home 作为主 DNS（推荐）

```
设备 → AdGuard Home (10.0.0.5:53)
         ↓ (上游)
       mihomo (10.0.0.4:53)
         ↓
      互联网
```

**优点**：
- ✅ 广告过滤优先
- ✅ 配置简单
- ✅ 统计数据完整

**适用场景**：大多数用户

### 方案 B：mihomo 作为主 DNS（高级）

```
设备 → mihomo (10.0.0.4:53)
         ↓
      AdGuard Home (通过代理规则分流)
         ↓
      互联网
```

**配置方法**：

1. 在 mihomo 配置中添加 DNS 重写：
```yaml
dns:
  enable: true
  nameserver:
    - 10.0.0.5  # AdGuard Home
```

2. 设备 DNS 指向 mihomo

**优点**：
- ✅ 分流优先
- ✅ DNS 查询也走代理规则

**缺点**：
- ❌ 配置较复杂
- ❌ AdGuard 统计不准确

**适用场景**：高级用户，需要 DNS 查询也分流的场景

### 方案 C：双栈配置（终极方案）

```
设备 → DNS1: AdGuard Home (10.0.0.5)
      → DNS2: mihomo (10.0.0.4)
```

**配置方法**：

1. AdGuard Home 上游 DNS：mihomo
2. 设备配置两个 DNS
3. 主 DNS 故障时自动切换

**优点**：
- ✅ 高可用
- ✅ 自动故障切换

## 🎨 个性化配置

### 为特定域名设置上游 DNS

AdGuard Home → 设置 → DNS 重写

```
# 强制某些域名使用特定 DNS
example.com → 8.8.8.8
```

### 为特定客户端设置规则

AdGuard Home → 设置 → 客户端设置

```
# 儿童设备使用严格过滤
MAC: xx:xx:xx:xx:xx:xx
使用家长控制
阻止成人内容
```

### DNS 缓存优化

**AdGuard Home 设置**：
```
设置 → DNS 设置 → DNS 缓存配置
缓存大小: 10000000 (10MB)
```

**mihomo 配置**：
```yaml
dns:
  enable: true
  cache: true
  cache-size: 10000
```

## 🚨 故障排查

### 问题 1：DNS 解析失败

**症状**：无法访问任何网站

**排查步骤**：

1. 检查 AdGuard Home 状态：
```bash
pct exec <adguard容器ID> -- /opt/AdGuardHome/AdGuardHome -s status
```

2. 检查 mihomo 状态：
```bash
pct exec <mihomo容器ID> -- systemctl status mihomo
```

3. 测试 DNS：
```bash
nslookup google.com 10.0.0.5
nslookup google.com 10.0.0.4
```

4. 查看日志：
```bash
# AdGuard Home 日志
pct exec <adguard容器ID> -- journalctl -u AdGuardHome -n 50

# mihomo 日志
pct exec <mihomo容器ID> -- journalctl -u mihomo -n 50
```

### 问题 2：部分网站打不开

**症状**：个别网站无法访问或加载慢

**可能原因**：

1. **被广告规则误杀**

   解决方法：在 AdGuard Home 查询日志中找到被拦截的域名，添加到白名单。

2. **DNS 污染**

   解决方法：确保 mihomo 的 DNS 配置正确，使用 DoH/DoT。

3. **代理节点问题**

   解决方法：在 Yacd 面板切换其他节点测试。

### 问题 3：广告拦截效果不佳

**排查步骤**：

1. 确认规则已更新：
```
AdGuard Home → 设置 → DNS 封锁清单 → 点击"更新"
```

2. 检查规则数量：
```
应该有 10 万+ 规则
```

3. 清除浏览器缓存

4. 尝试添加更多规则（参考规则文档）

### 问题 4：DNS 解析变慢

**可能原因**：

1. **规则太多** → 精简规则列表
2. **上游 DNS 慢** → 更换更快的 DNS 或优化网络
3. **容器资源不足** → 增加容器内存

**优化建议**：

```bash
# 查看容器资源使用
pct status <容器ID>

# 增加内存（在 PVE 上执行）
pct set <容器ID> -memory 1024
```

## 📊 性能优化

### 1. 资源分配建议

**mihomo 容器**：
```
CPU: 2 核
内存: 1024MB
磁盘: 4GB
```

**AdGuard Home 容器**：
```
CPU: 2 核
内存: 512MB（基础）/ 1024MB（进阶）
磁盘: 4GB
```

### 2. 网络优化

确保容器之间网络延迟低：
```bash
# 测试延迟
pct exec <adguard容器ID> -- ping -c 10 10.0.0.4
```

### 3. 日志管理

**定期清理日志**：

AdGuard Home：
```
设置 → 常规设置 → 查询日志
保留时间: 24 小时
```

mihomo：
```yaml
log-level: warning  # 减少日志输出
```

## 🔗 参考资源

- [mihomo 官方文档](https://wiki.metacubex.one/)
- [AdGuard Home 官方文档](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules)
- [anti-AD 项目](https://github.com/privacy-protection-tools/anti-AD)

## 💡 最佳实践

1. **先测试后上线**：在测试设备上验证配置无误后再应用到所有设备
2. **保持规则更新**：定期更新广告过滤规则
3. **监控日志**：定期查看日志发现异常
4. **备份配置**：定期备份两个容器的配置
5. **文档记录**：记录你的配置和修改，便于故障排查

## 🎉 总结

通过组合使用 mihomo 和 AdGuard Home，你可以获得：

✅ **广告过滤** - 拦截 95% 以上的广告  
✅ **智能分流** - 国内外流量智能识别  
✅ **DNS 无污染** - 使用 DoH/DoT 防止 DNS 污染  
✅ **隐私保护** - 阻止追踪器和恶意软件  
✅ **统一管理** - Web 界面管理所有设置  
✅ **全局生效** - 保护网络中所有设备  

享受干净、快速、安全的网络体验！ 🚀

