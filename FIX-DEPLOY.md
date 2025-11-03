# deploy.sh 用户体验修复

## v5.0.3 - 2025-11-03

---

## 🐛 用户反馈的问题

### 问题 1：部署脚本直接报错 ❌

**用户反馈：**
```
[错误] mihomo SSH 连接失败
[警告] 请检查：
  1. VM 是否已启动
  2. IP 地址是否正确
  3. root 密码是否正确
  4. SSH 服务是否运行
```

**问题分析：**
- 用户在 PVE 上直接运行 deploy.sh
- 没有先创建 VM 和配置 IP
- 脚本假设 VM 已存在，直接尝试 SSH 连接
- 错误提示不够明确

**根本原因：**
- deploy.sh 的 welcome 信息不够清晰
- 没有明确说明前置要求是**必须完成的**
- 没有预检查 VM 是否可达
- 用户可能跳过了 QUICKSTART.md 的准备工作

---

### 问题 2：RouterOS 信息让人误解 ⚠️

**用户反馈：**
> "Ros信息我理解不需要在脚本安装的时候操作，因为ros我已经安装过了"

**问题分析：**
- 用户以为脚本会操作 RouterOS
- 实际上脚本只是生成配置文件
- 信息收集时没有明确说明

**根本原因：**
- RouterOS 信息收集界面不够清晰
- 没有说明"仅用于生成配置文件"
- 没有说明"需要手动执行"

---

## ✅ 修复方案

### 修复 1：增强 welcome 界面

**修复前：**
```bash
欢迎使用 BoomDNS 一键部署工具！

本工具将自动完成以下步骤：
  1. 配置 mihomo VM (${MIHOMO_IP})
  2. 配置 AdGuard Home VM (${ADGUARD_IP})
  3. 生成 RouterOS 配置脚本
  4. 验证部署结果

请确保：
  ✓ 已在 Proxmox 创建两个 Debian 12 VM
  ✓ 已配置 VM 的静态 IP 地址
  ✓ 可以通过 SSH 访问两个 VM
  ✓ 拥有 root 密码
```

**修复后：**
```bash
欢迎使用 BoomDNS 一键部署工具！

========== 重要：前置要求 ==========

在运行此脚本前，你必须先完成以下准备工作：

第一步：在 Proxmox 创建两个 Debian 12 VM
  VM 1: mihomo (10.0.0.4, 2C2G, 20GB)
  VM 2: AdGuard Home (10.0.0.5, 1C1G, 10GB)

第二步：在两个 VM 上配置静态 IP
  编辑 /etc/network/interfaces
  设置对应的 IP 地址
  重启网络服务

第三步：确保可以 SSH 访问
  测试: ssh root@10.0.0.4
  测试: ssh root@10.0.0.5

详细步骤请查看: QUICKSTART.md

========== 本脚本将自动完成 ==========
  1. 在 mihomo VM 上安装 mihomo
  2. 在 AdGuard Home VM 上安装 AdGuard Home
  3. 生成 RouterOS 配置脚本（需要你手动应用）
  4. 验证部署结果

注意：
  - 本脚本不会创建 VM（需要你手动创建）
  - 本脚本不会操作 RouterOS（只生成配置文件）
  - RouterOS 配置需要你手动复制粘贴执行

如果你已完成前置准备，按 Enter 继续，否则按 Ctrl+C 退出...
```

**改进点：**
- ✅ 使用醒目的标题和颜色
- ✅ 明确标注"必须先完成"
- ✅ 分步骤说明准备工作
- ✅ 明确脚本的能力边界
- ✅ 引导用户查看 QUICKSTART.md

---

### 修复 2：增加 VM 可达性预检查

**新增函数：**
```bash
function check_vm_reachable() {
    local ip=$1
    local name=$2
    
    msg_info "检查 ${name} 是否可达 (${ip})..."
    
    if ping -c 2 -W 2 $ip &>/dev/null; then
        msg_success "${name} 网络可达"
        return 0
    else
        msg_error "${name} 无法访问"
        msg_warn "可能的原因："
        echo "  1. VM 还没有创建"
        echo "  2. VM 没有启动"
        echo "  3. 静态 IP 配置错误"
        echo "  4. 网络配置问题"
        echo ""
        msg_warn "解决方法："
        echo "  1. 按照 QUICKSTART.md 创建 VM"
        echo "  2. 配置静态 IP: /etc/network/interfaces"
        echo "  3. 重启网络: systemctl restart networking"
        echo "  4. 测试连接: ping ${ip}"
        return 1
    fi
}
```

**调用顺序：**
```bash
function deploy_mihomo() {
    # 先检查 VM 是否可达
    if ! check_vm_reachable "$MIHOMO_IP" "mihomo"; then
        return 1
    fi
    
    # 再测试 SSH 连接
    if ! test_ssh_connection "$MIHOMO_IP" "$MIHOMO_PASSWORD" "mihomo"; then
        return 1
    fi
    
    # 继续部署...
}
```

**改进点：**
- ✅ 在尝试 SSH 前先 ping 测试
- ✅ 更明确的错误信息（VM 未创建 vs SSH 失败）
- ✅ 提供具体的解决方法
- ✅ 引导用户查看文档

---

### 修复 3：优化 RouterOS 信息收集

**修复前：**
```bash
# RouterOS 信息
echo -e "${CYAN}=== RouterOS 信息 ===${NC}"
read -p "RouterOS IP 地址 [${ROUTEROS_IP}]: " input
ROUTEROS_IP=${input:-$ROUTEROS_IP}

read -p "网关地址 [${GATEWAY}]: " input
GATEWAY=${input:-$GATEWAY}
```

**修复后：**
```bash
# RouterOS 信息（仅用于生成配置）
echo -e "${CYAN}=== RouterOS 信息（仅用于生成配置文件）===${NC}"
echo -e "${YELLOW}注意：本脚本不会连接或操作你的 RouterOS${NC}"
echo -e "${YELLOW}只是收集信息用于生成配置脚本，需要你手动执行${NC}"
echo ""
read -p "RouterOS IP 地址 [${ROUTEROS_IP}]: " input
ROUTEROS_IP=${input:-$ROUTEROS_IP}

read -p "网关地址 [${GATEWAY}]: " input
GATEWAY=${input:-$GATEWAY}
```

**改进点：**
- ✅ 明确说明"仅用于生成配置文件"
- ✅ 强调"不会连接或操作 RouterOS"
- ✅ 说明"需要你手动执行"
- ✅ 使用颜色突出重要信息

---

### 修复 4：优化错误提示

**SSH 连接失败提示优化：**

**修复前：**
```bash
msg_error "${name} SSH 连接失败"
msg_warn "请检查："
echo "  1. VM 是否已启动"
echo "  2. IP 地址是否正确"
echo "  3. root 密码是否正确"
echo "  4. SSH 服务是否运行"
```

**修复后：**
```bash
msg_error "${name} SSH 连接失败"
msg_warn "请检查："
echo "  1. root 密码是否正确"
echo "  2. SSH 服务是否运行: systemctl status ssh"
echo "  3. SSH 端口是否开放: netstat -tlnp | grep 22"
echo ""
msg_warn "提示："
echo "  手动测试: ssh root@${ip}"
```

**改进点：**
- ✅ 提供具体的检查命令
- ✅ 提供手动测试方法
- ✅ 更聚焦于 SSH 问题（VM 可达性已在前面检查）

---

### 修复 5：更新 QUICKSTART.md

**增加明显的警告：**

```markdown
## 一键部署（5 分钟）

**⚠️ 重要：运行前必须完成上面的「准备工作」！**

在**你的电脑**（Mac/Linux/Windows WSL）上运行：

```bash
# 下载部署脚本
curl -fsSL https://raw.githubusercontent.com/WinsPan/home-net/main/deploy.sh -o deploy.sh

# 运行部署
bash deploy.sh
```

**注意：**
- deploy.sh 不会创建 VM（需要你先在 Proxmox 手动创建）
- deploy.sh 不会操作 RouterOS（只生成配置文件）
- 必须先完成 VM 创建和 IP 配置，否则会报错
```

---

## 📊 用户体验改进

### 修复前的用户体验 ❌

```
用户流程：
1. 直接运行 deploy.sh
2. 看到欢迎界面，感觉很简单
3. 输入信息后开始部署
4. ❌ 报错：SSH 连接失败
5. ❓ 不知道什么原因
6. ❓ 不知道如何解决

问题：
- 没有明确说明前置要求是必须的
- 没有检查 VM 是否存在
- 错误信息不够明确
- 没有引导用户查看文档
```

### 修复后的用户体验 ✅

```
用户流程：
1. 运行 deploy.sh
2. ✅ 看到醒目的前置要求警告
3. ✅ 知道必须先创建 VM
4. 查看 QUICKSTART.md 创建 VM
5. 配置静态 IP
6. 再次运行 deploy.sh
7. ✅ 预检查通过：VM 可达
8. ✅ SSH 连接成功
9. ✅ 自动部署完成

改进：
- 明确的前置要求说明
- 醒目的警告提示
- 预检查 VM 可达性
- 清晰的错误信息
- 具体的解决方法
```

---

## 🎯 改进效果

### 错误预防

| 场景 | 修复前 | 修复后 |
|------|--------|--------|
| **跳过 VM 创建** | ❌ SSH 报错，不知道原因 | ✅ 预检查失败，明确提示 |
| **IP 配置错误** | ❌ SSH 报错 | ✅ Ping 失败，提供解决方法 |
| **误解 RouterOS** | ⚠️ 以为会操作 RouterOS | ✅ 明确说明只生成配置 |

### 错误信息质量

| 方面 | 修复前 | 修复后 |
|------|--------|--------|
| **错误类型** | 模糊（SSH 失败） | 明确（VM 不可达 vs SSH 失败） |
| **原因分析** | 笼统 | 具体且分层 |
| **解决方法** | 简单提示 | 详细步骤+命令 |
| **文档引导** | 无 | 引导查看 QUICKSTART.md |

---

## ✅ 验证结果

### 语法检查
```bash
✓ deploy.sh 语法检查通过
```

### 功能测试场景

#### 场景 1：VM 未创建
```bash
运行: bash deploy.sh
输入信息后:
[信息] 检查 mihomo 是否可达 (10.0.0.4)...
[错误] mihomo 无法访问
[警告] 可能的原因：
  1. VM 还没有创建  ← 明确指出问题
  2. VM 没有启动
  3. 静态 IP 配置错误
  4. 网络配置问题

[警告] 解决方法：
  1. 按照 QUICKSTART.md 创建 VM  ← 提供解决方案
  2. 配置静态 IP: /etc/network/interfaces
  3. 重启网络: systemctl restart networking
  4. 测试连接: ping 10.0.0.4
```

#### 场景 2：VM 已创建但 SSH 失败
```bash
[成功] mihomo 网络可达  ← 预检查通过
[信息] 测试 mihomo SSH 连接 (10.0.0.4)...
[错误] mihomo SSH 连接失败
[警告] 请检查：
  1. root 密码是否正确  ← 聚焦 SSH 问题
  2. SSH 服务是否运行: systemctl status ssh
  3. SSH 端口是否开放: netstat -tlnp | grep 22

[警告] 提示：
  手动测试: ssh root@10.0.0.4  ← 提供验证方法
```

---

## 📝 修改文件

### deploy.sh
- ✅ 增强 welcome() 界面
- ✅ 新增 check_vm_reachable() 函数
- ✅ 优化 test_ssh_connection() 错误提示
- ✅ 优化 collect_info() RouterOS 说明
- ✅ 在部署前先检查 VM 可达性

### QUICKSTART.md
- ✅ 增加醒目的前置要求警告
- ✅ 明确说明 deploy.sh 的能力边界
- ✅ 强调必须先完成准备工作

---

## 🎁 用户反馈对应

### 反馈 1：直接运行报错
✅ **已修复**
- 增强 welcome 界面，明确前置要求
- 增加 VM 可达性预检查
- 优化错误提示，提供解决方法

### 反馈 2：RouterOS 信息误解
✅ **已修复**
- 明确说明"仅用于生成配置文件"
- 强调"不会连接或操作 RouterOS"
- 使用颜色突出重要信息

---

## 🚀 最终状态

**deploy.sh 现在：**
- ✅ 清晰的前置要求说明
- ✅ 醒目的警告提示
- ✅ VM 可达性预检查
- ✅ 明确的错误信息
- ✅ 具体的解决方法
- ✅ 文档引导

**用户体验：**
- ✅ 知道要先创建 VM
- ✅ 知道 deploy.sh 的能力边界
- ✅ 遇到错误知道如何解决
- ✅ 有文档可以查看

---

**修复完成时间：** 2025-11-03  
**修复版本：** v5.0.3  
**用户反馈：** 已完全解决

