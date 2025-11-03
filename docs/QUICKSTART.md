# 快速入门指南

这是一个 5 分钟快速入门指南，帮助您快速部署 mihomo 代理服务。

## 🚀 第一步：在 Proxmox 上部署

### 1. 登录 Proxmox Web 界面

打开浏览器访问：`https://your-proxmox-ip:8006`

### 2. 打开 Shell

点击您的 Proxmox 节点 → 点击 **Shell** 按钮

### 3. 运行部署脚本

在 Shell 中执行以下命令：

```bash
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/create-mihomo-lxc.sh)
```

### 4. 按照提示配置

```
请输入容器 ID: [直接回车使用默认值]
请输入容器名称: [直接回车或输入自定义名称]
请选择存储位置: [直接回车使用 local-lvm]
请输入磁盘大小: [直接回车使用 4GB]
请输入 CPU 核心数: [直接回车使用 2 核]
请输入内存大小: [直接回车使用 1024MB]
请输入网络桥接: [直接回车使用 vmbr0]

网络配置选项:
1) DHCP (自动获取 IP)
2) 静态 IP
请选择: [输入 1 或直接回车]

请输入 root 密码: [输入一个强密码]
```

### 5. 等待安装完成

大约 3-5 分钟后，您会看到：

```
╔══════════════════════════════════════════════════════╗
║              mihomo 容器部署完成！                    ║
╚══════════════════════════════════════════════════════╝

容器信息:
  容器 ID: 100
  容器名称: mihomo
  容器 IP: 192.168.1.100

mihomo 服务:
  混合端口: 192.168.1.100:7890
  控制面板: http://192.168.1.100:9090
```

**记下容器 IP 地址！** 📝

## ⚙️ 第二步：配置代理节点

### 1. 进入容器

在 Proxmox Shell 中执行：

```bash
pct enter 100  # 100 是您的容器 ID
```

### 2. 编辑配置文件

```bash
nano /etc/mihomo/config.yaml
```

### 3. 添加您的代理节点

找到 `proxies:` 部分，添加您的节点信息：

**示例 - Shadowsocks:**
```yaml
proxies:
  - name: "我的节点"
    type: ss
    server: your-server.com
    port: 8388
    cipher: aes-256-gcm
    password: "your-password"
```

**示例 - VMess:**
```yaml
proxies:
  - name: "我的节点"
    type: vmess
    server: your-server.com
    port: 443
    uuid: "your-uuid"
    alterId: 0
    cipher: auto
    tls: true
```

**示例 - Trojan:**
```yaml
proxies:
  - name: "我的节点"
    type: trojan
    server: your-server.com
    port: 443
    password: "your-password"
```

### 4. 更新代理组

找到 `proxy-groups:` 部分，将您的节点添加到组中：

```yaml
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - 我的节点  # 添加您的节点名称
      - DIRECT
```

### 5. 保存并退出

- 按 `Ctrl + O` 保存
- 按 `Enter` 确认
- 按 `Ctrl + X` 退出

### 6. 重启服务

```bash
systemctl restart mihomo
```

### 7. 检查状态

```bash
systemctl status mihomo
```

看到 `active (running)` 就表示成功了！✅

### 8. 退出容器

```bash
exit
```

## 🌐 第三步：配置客户端

### 方法 1：浏览器配置（推荐新手）

#### Chrome/Edge + SwitchyOmega

1. 安装 **Proxy SwitchyOmega** 扩展
2. 新建情景模式（代理服务器）
3. 配置：
   - 代理协议：`HTTP`
   - 代理服务器：`192.168.1.100`（您的容器 IP）
   - 代理端口：`7890`
4. 点击保存
5. 点击扩展图标切换到刚创建的模式

#### Firefox

1. 设置 → 网络设置 → 手动代理配置
2. HTTP 代理：`192.168.1.100`，端口：`7890`
3. 勾选 "将此代理用于所有协议"
4. 点击确定

### 方法 2：系统代理配置

#### Windows

1. 设置 → 网络和 Internet → 代理
2. 手动设置代理
3. 地址：`192.168.1.100`
4. 端口：`7890`
5. 点击保存

#### macOS

1. 系统偏好设置 → 网络
2. 选择当前网络 → 高级
3. 代理选项卡
4. 勾选 "网页代理(HTTP)" 和 "安全网页代理(HTTPS)"
5. 服务器：`192.168.1.100`，端口：`7890`
6. 点击好

#### Linux

在终端中：
```bash
export http_proxy="http://192.168.1.100:7890"
export https_proxy="http://192.168.1.100:7890"
```

### 方法 3：Web 控制面板（推荐）

1. 打开浏览器访问：[http://yacd.metacubex.one](http://yacd.metacubex.one)
2. 输入 API 地址：`http://192.168.1.100:9090`（您的容器 IP）
3. 点击 "Add" 添加

现在您可以：
- 查看实时流量
- 切换代理节点
- 查看连接信息
- 测试节点延迟

## 🧪 第四步：测试代理

### 测试方法 1：浏览器

访问：[https://www.google.com](https://www.google.com)

如果能访问，说明代理工作正常！🎉

### 测试方法 2：命令行

在终端执行：
```bash
curl -x http://192.168.1.100:7890 https://www.google.com -I
```

看到 `HTTP/2 200` 就表示成功！

### 测试方法 3：检查 IP

访问：[https://ip.sb](https://ip.sb)

应该显示您代理服务器的 IP 地址，而不是本地 IP。

## 📱 移动设备配置

### iOS/iPadOS

1. 设置 → Wi-Fi
2. 点击当前连接的网络右侧的 (i) 图标
3. 滚动到底部 → 配置代理 → 手动
4. 服务器：`192.168.1.100`
5. 端口：`7890`
6. 存储

### Android

1. 设置 → WLAN
2. 长按当前连接的网络 → 修改网络
3. 高级选项 → 代理 → 手动
4. 代理服务器主机名：`192.168.1.100`
5. 代理服务器端口：`7890`
6. 保存

## 🎯 常见问题

### Q: 无法连接到代理？

**检查清单：**

1. ✅ 容器是否在运行？
```bash
pct status 100  # 100 是您的容器 ID
```

2. ✅ mihomo 服务是否在运行？
```bash
pct exec 100 -- systemctl status mihomo
```

3. ✅ 防火墙是否阻止？
```bash
# 在容器内执行
ss -tuln | grep 7890
```

4. ✅ 网络是否连通？
```bash
ping 192.168.1.100  # 您的容器 IP
```

### Q: 配置修改后不生效？

**解决方法：**

重启服务：
```bash
pct exec 100 -- systemctl restart mihomo
```

### Q: 如何查看日志？

```bash
pct exec 100 -- journalctl -u mihomo -f
```

### Q: 如何停止代理？

- **浏览器**：SwitchyOmega 切换到"直接连接"
- **系统代理**：关闭代理设置
- **停止服务**：`pct exec 100 -- systemctl stop mihomo`

## 📚 进阶使用

想了解更多高级功能？查看：

- [完整使用文档](USAGE.md)
- [配置示例](config-examples.yaml)
- [README](../README.md)

## 🆘 获取帮助

遇到问题？

1. 查看日志：`pct exec 100 -- journalctl -u mihomo -n 50`
2. 提交 Issue 到 GitHub
3. 查阅 [mihomo 官方文档](https://wiki.metacubex.one/)

---

**恭喜！🎉 您已经成功部署并配置了 mihomo 代理服务！**

现在您可以畅游互联网了！🌍✨

