# AdGuard Home 广告过滤规则配置指南

本文档提供 AdGuard Home 的广告过滤规则配置方案，规则来源参考了优秀的开源项目。

## 📋 规则来源

本项目推荐的规则主要来自以下优秀项目：

- [Aethersailor/Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules) - 分流完善的 OpenClash 规则
- [Lanlan13-14/Rules](https://github.com/Lanlan13-14/Rules) - 综合规则集
- [privacy-protection-tools/anti-AD](https://github.com/privacy-protection-tools/anti-AD) - 反广告规则
- [217heidai/adblockfilters](https://github.com/217heidai/adblockfilters) - 广告过滤规则
- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) - 综合广告规则

## 🚀 快速配置

### 方法一：自动导入规则（推荐）

在容器中执行自动配置脚本：

```bash
pct enter <容器ID>
bash <(curl -s https://raw.githubusercontent.com/WinsPan/home-net/main/scripts/misc/setup-adguard-rules.sh)
```

### 方法二：手动配置规则

#### 1. 访问 AdGuard Home 管理面板

```
http://<容器IP>:3000
```

#### 2. 进入过滤器设置

设置 → DNS 封锁清单

#### 3. 添加过滤规则

点击 "添加阻止列表" → "添加自定义列表"

## 📝 推荐规则列表

### 🇨🇳 国内规则（强烈推荐）

#### anti-AD（反广告联盟）
```
名称: anti-AD
URL: https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt
说明: 国内最全面的广告过滤规则，持续更新
```

#### AdGuard DNS Filter（中文优化）
```
名称: AdGuard DNS Filter 中文
URL: https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt
说明: 针对中文网站优化的规则
```

#### 乘风视频过滤规则
```
名称: 乘风视频过滤
URL: https://raw.githubusercontent.com/xinggsf/Adblock-Plus-Rule/master/mv.txt
说明: 过滤视频网站广告
```

### 🌍 国际规则

#### AdGuard DNS Filter
```
名称: AdGuard DNS Filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
说明: AdGuard 官方规则，涵盖全球广告
```

#### EasyList
```
名称: EasyList
URL: https://easylist-downloads.adblockplus.org/easylist.txt
说明: 国际最常用的广告过滤规则
```

#### EasyPrivacy
```
名称: EasyPrivacy
URL: https://easylist-downloads.adblockplus.org/easyprivacy.txt
说明: 隐私保护规则，阻止追踪器
```

### 🎯 专项规则

#### 反恶意软件
```
名称: AdGuard Malware Filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/malware.txt
说明: 恶意软件和钓鱼网站拦截
```

#### 反跟踪
```
名称: AdGuard Tracking Protection
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/tracking.txt
说明: 阻止各类追踪器
```

#### 反社交媒体追踪
```
名称: AdGuard Social Media Filter
URL: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/social.txt
说明: 阻止社交媒体追踪按钮
```

### 📱 移动端优化

#### AdGuard Mobile Filter
```
名称: AdGuard Mobile Ads
URL: https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_11_Mobile/filter.txt
说明: 移动端广告过滤
```

### 🎮 特定平台规则

#### YouTube 广告
```
名称: YouTube Ads
URL: https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/youtubelist.txt
说明: YouTube 广告拦截（部分有效）
```

#### Twitch 广告
```
名称: Twitch Ads
URL: https://raw.githubusercontent.com/pixeltris/TwitchAdSolutions/master/dns-blocklist.txt
说明: Twitch 直播广告拦截
```

## 🛠️ 完整配置示例

### 基础套餐（适合新手）

```
1. anti-AD                       # 国内广告
2. AdGuard DNS Filter            # 国际广告
3. EasyList                      # 基础规则
4. AdGuard Malware Filter        # 恶意软件
```

**效果**: 能拦截 90% 以上的常见广告

### 进阶套餐（推荐）

```
1. anti-AD                       # 国内广告
2. AdGuard DNS Filter 中文       # 国内优化
3. 乘风视频过滤                  # 视频广告
4. AdGuard DNS Filter            # 国际广告
5. EasyList                      # 基础规则
6. EasyPrivacy                   # 隐私保护
7. AdGuard Malware Filter        # 恶意软件
8. AdGuard Tracking Protection   # 反追踪
```

**效果**: 能拦截 95% 以上的广告，并保护隐私

### 完整套餐（追求极致）

在进阶套餐基础上添加：

```
9. AdGuard Social Media Filter   # 社交媒体
10. AdGuard Mobile Ads           # 移动端
11. YouTube Ads                  # YouTube
12. 其他专项规则...
```

**注意**: 规则过多可能影响 DNS 解析速度，建议根据需求选择

## ⚙️ 高级配置

### 1. 自定义规则

在 "自定义过滤规则" 中添加：

```
# 屏蔽特定域名
||ads.example.com^
||tracking.example.com^

# 屏蔽整个域名及子域名
||example.com^

# 放行特定域名（白名单）
@@||trusted.example.com^

# 正则表达式屏蔽
/^ad[sx]?[0-9]*\..*$/
```

### 2. DNS 重写规则

设置 → DNS 重写

```
# 加速 GitHub
github.com → 20.205.243.166
raw.githubusercontent.com → 185.199.108.133

# 本地服务
nas.local → 192.168.1.10
router.local → 192.168.1.1
```

### 3. 上游 DNS 配置

#### 国内 DNS（推荐）

```
# 阿里 DNS
https://dns.alidns.com/dns-query
223.5.5.5
223.6.6.6

# 腾讯 DNS
https://doh.pub/dns-query
119.29.29.29

# 114 DNS
114.114.114.114
```

#### 国际 DNS

```
# Cloudflare
https://cloudflare-dns.com/dns-query
1.1.1.1
1.0.0.1

# Google
https://dns.google/dns-query
8.8.8.8
8.8.4.4
```

#### 混合配置（推荐）

```
# 主 DNS（国内）
https://dns.alidns.com/dns-query
https://doh.pub/dns-query

# 备用 DNS（国际）
https://cloudflare-dns.com/dns-query
https://dns.google/dns-query

# 平行请求（可选）
勾选 "并行请求"
```

### 4. 查询日志设置

设置 → 常规设置 → 查询日志

```
查询日志保留时间: 24 小时（适中）
统计数据保留时间: 90 天（根据需要调整）
```

### 5. 客户端设置

设置 → 客户端设置

```
# 为特定客户端指定不同规则
Name: 儿童设备
MAC: xx:xx:xx:xx:xx:xx
使用家长控制规则
```

## 🔍 规则验证

### 测试广告拦截

访问以下网站测试拦截效果：

```
1. https://ads-blocker.com/zh-CN/testing/
2. https://d3ward.github.io/toolz/adblock.html
3. https://www.detectadblock.com/
```

### 查看拦截统计

AdGuard Home 面板 → 仪表板

```
- 查询总数
- 已拦截查询
- 拦截率
- 热门域名
```

## 🚨 常见问题

### Q: 某些网站打不开或功能异常？

**A**: 可能被误杀，解决方法：

1. 在查询日志中找到被拦截的域名
2. 添加到白名单：
```
设置 → 过滤器 → 自定义过滤规则
@@||被拦截的域名^
```

### Q: 视频网站还是有广告？

**A**: 视频广告拦截比较复杂：

- YouTube/Twitch: DNS 拦截效果有限，建议使用浏览器插件
- 国内视频网站: 可尝试 "乘风视频过滤" 规则
- 最佳方案: AdGuard Home + 浏览器插件

### Q: 移动 APP 广告拦截效果？

**A**: 
- 大部分 APP 广告可以拦截
- 部分内嵌广告无法拦截（如视频 APP 的贴片广告）
- 建议配合移动端广告规则使用

### Q: DNS 解析变慢？

**A**: 可能原因和解决方法：

1. 规则太多 → 精简规则列表
2. 上游 DNS 慢 → 更换更快的 DNS
3. 缓存不足 → 增加缓存大小（设置 → DNS 设置 → DNS 缓存配置）

### Q: 如何更新规则？

**A**: AdGuard Home 会自动更新规则，也可以手动更新：

```
设置 → DNS 封锁清单 → 点击"更新"按钮
```

## 📊 性能优化

### 1. 缓存设置

```
设置 → DNS 设置 → DNS 缓存配置
缓存大小: 10000000（10MB，根据内存调整）
```

### 2. 并行请求

```
设置 → DNS 设置
勾选 "使用并行查询加快解析速度"
```

### 3. 规则优化

```
定期检查规则列表：
- 移除不再维护的规则
- 合并重复的规则
- 只保留必要的规则
```

## 🔗 参考资源

- [AdGuard Home 官方文档](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [AdGuard 规则语法](https://kb.adguard.com/en/general/how-to-create-your-own-ad-filters)
- [Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules)
- [anti-AD 项目](https://github.com/privacy-protection-tools/anti-AD)

## 💡 最佳实践

1. **从基础套餐开始**: 不要一次性添加太多规则
2. **定期检查日志**: 了解拦截情况，及时处理误杀
3. **建立白名单**: 将信任的网站加入白名单
4. **配合浏览器插件**: 对于难以拦截的广告使用插件辅助
5. **定期更新**: 保持规则列表更新以应对新的广告形式

---

**提示**: 广告拦截是一个持续的过程，需要根据实际使用情况不断调整规则。

