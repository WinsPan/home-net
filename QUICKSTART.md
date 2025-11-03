# 快速开始

**最简单的部署方式 - 15分钟完成**

---

## 前提条件

- ✅ Proxmox VE 服务器
- ✅ Debian 12 ISO 文件（放在 Proxmox local 存储）
- ✅ MikroTik RouterOS 路由器
- ✅ 机场订阅地址

---

## 部署步骤

### 1. 在 Proxmox 节点运行脚本

**SSH 连接到 Proxmox 节点：**

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh

# 运行（需要 root 权限）
bash deploy.sh
```

### 2. 按提示输入信息

```
Proxmox 节点名称: [当前节点]
存储池名称: [local-lvm]
网络桥接: [vmbr0]
mihomo IP: [10.0.0.4]
AdGuard Home IP: [10.0.0.5]
网关: [10.0.0.2]
VM root 密码: ******
机场订阅地址: https://your-subscription-url
```

### 3. 完成 VM 系统安装

脚本会创建 VM 并启动，你需要在 Proxmox 控制台完成系统安装：

**mihomo VM (100):**
```
1. Install
2. 语言: English
3. 主机名: mihomo
4. Root 密码: 你设置的密码
5. 分区: Guided - use entire disk
6. 软件: SSH server
7. 完成安装
```

**AdGuard Home VM (101):**
```
同上，主机名改为: adguardhome
```

### 4. 初始化 AdGuard Home

**访问：** `http://10.0.0.5:3000`

**DNS 设置：**
```
上游 DNS 服务器（删除默认，添加）：
  https://doh.pub/dns-query
  https://dns.alidns.com/dns-query
  223.5.5.5
  119.29.29.29

Bootstrap DNS：
  223.5.5.5
  119.29.29.29

勾选：
  ☑ 启用并行请求
  ☑ 启用 DNSSEC
```

**添加过滤规则：**
```
过滤器 → DNS 封锁清单 → 添加自定义列表

规则 1：Anti-AD
https://anti-ad.net/easylist.txt

规则 2：AdGuard Filter
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

规则 3：EasyList China
https://easylist-downloads.adblockplus.org/easylistchina.txt

点击「立即更新过滤器」
```

### 5. 配置 RouterOS

打开生成的 `routeros-config.rsc` 文件，复制所有内容

登录 RouterOS（Winbox 或 SSH），逐行粘贴执行

**⚠️ 重要：** 将 `ether1` 改为你的实际 WAN 口名称

### 6. 设置设备代理

**Windows:**
```
设置 → 网络 → 代理
地址: 10.0.0.4
端口: 7890
```

**macOS:**
```
系统偏好设置 → 网络 → 高级 → 代理
HTTP: 10.0.0.4:7890
HTTPS: 10.0.0.4:7890
```

**浏览器（推荐）:**
```
安装 SwitchyOmega 扩展
代理: 10.0.0.4:7890
```

---

## 测试验证

### 测试代理
```bash
curl -x http://10.0.0.4:7890 https://www.google.com -I
# 应该返回 200 OK
```

### 测试广告拦截
```
浏览器访问: http://testadblock.com
应该显示: 广告被拦截
```

### 管理界面
```
mihomo:       http://10.0.0.4:9090
AdGuard Home: http://10.0.0.5
```

---

## 完成！🎉

你现在拥有：
- ✅ 智能分流
- ✅ 广告过滤
- ✅ 容错保护

---

## 常见问题

### 系统安装失败
- 检查 Debian ISO 是否在 local 存储
- 确认 ISO 文件名：`debian-12-generic-amd64.iso`

### SSH 连接超时
- 确认 VM 已启动
- 确认网络配置正确
- 手动配置 IP：编辑 `/etc/network/interfaces`

### 更多帮助
- [完整配置](docs/CONFIG.md)
- [命令速查](CHEATSHEET.md)
- [GitHub Issues](https://github.com/WinsPan/home-net/issues)

---

**项目地址:** https://github.com/WinsPan/home-net
