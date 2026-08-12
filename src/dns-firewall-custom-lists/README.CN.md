<div align="center">
  <a href="README.md">English</a> |
  <a href="README.CN.md">中文</a>
</div>

# IPFire DNS 防火墙自定义列表扩展

适用于 **IPFire 2.29 Core Update 203**。本扩展在现有“DNS 防火墙”页面中加入自定义 RPZ 列表管理，并保留官方列表原有的启用、停用和访问控制功能。

![DNS 防火墙自定义列表](images/custom_dnsbl.png)

## 功能

- 在列表页“保存”左侧增加“添加”按钮。
- 添加、编辑、删除自定义 HTTPS RPZ 列表。
- 编辑名称、Zone、Primary、RPZ URL、说明、许可证和访问控制。
- 官方列表的名称、Zone、Primary、说明和许可证只读，访问控制仍可编辑。
- 自定义列表独立保存在 `/var/ipfire/dns/custom_dnsbl.json`，不会被官方 `dnsbl.json` 更新覆盖。
- HTTPS 源使用 `ETag` 和 `Last-Modified` 条件请求；未变化时返回 `304`，不会重复下载完整文件。
- 下载后检查 HTML 错误页和 SOA 记录；验证通过后原子替换，失败时保留现有规则。
- 自定义 HTTPS RPZ 与官方列表共用 `/usr/local/bin/update-rpzs`、同一把锁和同一次 DNS reload。
- 英文、简体中文界面；其他语言自动回退为英文。

## 通过社区仓库安装

```sh
ipfrepo update
ipfrepo install dns-firewall-custom-lists
```

## 从源码安装

将源码目录复制到 IPFire，以 root 登录后执行：

```sh
cd dns-firewall-custom-lists
./install.sh
```

安装脚本会：

1. 检查 Core 版本、依赖和脚本语法；
2. 将原文件备份到 `/root/dns-firewall-custom-lists-backup-时间戳/`；
3. 安装 CGI、统一更新脚本和语言条目；
4. 重建语言缓存、创建互斥锁并重新加载 DNS。

安装不会删除已有自定义列表配置。

## 卸载

使用社区仓库安装时执行：

```sh
ipfrepo remove dns-firewall-custom-lists
```

从源码安装时，在源码目录执行：

```sh
./uninstall.sh
```

卸载程序恢复首次安装时保存的官方 `dnsbl.cgi` 和 `update-rpzs`，移除扩展语言条目、锁文件及遗留调度任务。自定义列表配置和 RPZ 文件会先备份到 `/root/dns-firewall-custom-lists-uninstall-时间戳/`，再从运行配置中清理。

## 使用

打开 `https://IPFire地址:444/cgi-bin/dnsbl.cgi`。

1. 点击“添加”，填写列表名称和 HTTPS RPZ URL。
2. 新列表默认启用并立即在后台下载；初次下载完成前不会影响现有 DNS 数据。
3. 点击铅笔图标可编辑列表信息和访问控制。
4. 在主列表勾选或取消勾选后点击“保存”，使拦截状态生效。
5. 垃圾桶图标只显示在自定义列表上，删除时同时清理配置、RPZ 文件和 HTTP 缓存标识。

论坛示例 OISD：

- 名称：`OISD`
- URL：`https://big.oisd.nl/rpz`
- 说明：`OISD Big blocklist (recommended in IPFire forum)`
- 许可证：`https://github.com/sjhgvr/oisd/blob/main/LICENSE`

## 更新机制

执行官方 `dnsctrl sync-rpzs` 时，`/usr/local/bin/update-rpzs` 先通过 AXFR/IXFR 同步启用的官方列表，再对启用的自定义 HTTPS RPZ 发起条件请求，最后统一重新加载 DNS。整个过程只持有一把 `/var/ipfire/dns/rpz-update.lock`，不会发生官方与自定义列表并发写入。

如果 HTTPS 服务器的 `ETag` 或 `Last-Modified` 没有变化，将返回 `304 Not Modified`，不会传输列表正文。只有源文件发生变化时才下载、验证并原子替换。OISD 不提供 AXFR/IXFR 服务，因此条件 HTTPS 请求是该源可用的增量检查方式。

因此，自定义列表与官方列表具有相同的更新触发时机：IPFire 的 `%hourly,random` fcron 每小时随机执行一次；在 DNS 防火墙页面保存列表状态或手动执行官方同步命令也会触发更新。禁用的自定义列表不会检查或下载。

检查日志：

```sh
grep update-rpzs /var/log/messages
```

手动检查更新：

```sh
/usr/local/bin/dnsctrl sync-rpzs
```

## 文件

- `/srv/web/ipfire/cgi-bin/dnsbl.cgi`
- `/usr/local/bin/update-rpzs`
- `/var/ipfire/dns/custom_dnsbl.json`
- `/var/ipfire/dns/rpz-update.lock`
- `/var/ipfire/dns/custom-lists-original/`（卸载恢复基线）

## 已验证

在 IPFire 2.29 x86_64 Core 203 上完成：安装语法、英/中文界面、添加、编辑、删除、启用/停用、实际 DNS 拦截、HTTP 304 条件更新、失败保留、文件原子替换、官方/自定义统一更新和 DNS 正常域回归测试。

> 自定义 RPZ 内容、可用性和许可证由列表提供者负责；部署前请自行确认合规性。
