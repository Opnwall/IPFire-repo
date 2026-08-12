# 给 IPFire DNS 防火墙增加自定义 RPZ 列表：安装、更新机制与实测

IPFire 自带的 DNS 防火墙提供了广告、恶意软件、钓鱼、成人内容等官方 RPZ 分类，但原生界面目前不能直接添加第三方 RPZ 源。为了方便在 WebGUI 中管理 OISD 等自定义列表，我制作了一个非官方扩展：**IPFire DNS Firewall Custom Lists 1.1.2**。

该扩展适用于 **IPFire 2.29（x86_64）Core Update 203**。它将自定义列表整合进现有 DNS 防火墙页面和官方更新流程，不需要额外运行一套定时更新程序。

> 这是社区测试性质的非官方补丁，并非 IPFire 官方组件。安装前请做好备份，并自行确认第三方列表的可靠性、内容和许可证。

![DNS 防火墙自定义列表](images/custom_dnsbl.png)

## 主要功能

- 在 DNS 防火墙列表页增加“添加”按钮；
- 通过 HTTPS URL 添加自定义 RPZ 列表；
- 支持编辑名称、Zone、Primary、RPZ URL、说明、许可证和访问控制；
- 自定义列表可以像官方列表一样启用或停用；
- 自定义列表提供编辑和删除图标；
- 官方列表的元数据保持只读，访问控制仍可修改；
- 提供英文和简体中文界面，其他语言回退为英文；
- 自定义配置独立保存，不会被官方 `dnsbl.json` 更新覆盖；
- 提供安装和卸载脚本，并自动备份被替换的文件。

1.1.2 还修复了一个界面细节：在添加或编辑页面中，即使必填字段为空，点击“返回（Back）”也不会触发浏览器原生字段校验。这样可以避免英文 WebGUI 中出现由中文浏览器环境生成的“请填写此字段”提示。

## 为什么没有每小时完整下载

早期实现会在每次更新时完整下载 HTTPS RPZ。对于 OISD Big 这类大型列表，这会造成不必要的带宽、存储写入和解析开销。

现在，自定义 HTTPS 源使用标准 HTTP 条件请求：

- 记录服务器返回的 `ETag`；
- 记录 `Last-Modified`；
- 下次更新时发送 `If-None-Match` 和 `If-Modified-Since`；
- 文件未变化时，服务器返回 `304 Not Modified`，不传输完整正文；
- 只有内容确实变化时才重新下载和安装。

官方 IPFire RPZ 仍通过 AXFR/IXFR 同步。OISD 等只提供 HTTPS 文件、没有开放 AXFR/IXFR 的第三方源，则使用条件 HTTP 请求。这不是 DNS 层面的增量传输，但能够避免无变化时的重复完整下载。

## 统一更新流程

自定义列表没有单独的 `update-custom-rpzs` 任务，而是整合到 IPFire 现有的：

```text
/usr/local/bin/update-rpzs
```

IPFire 的 `%hourly,random` fcron 任务每小时在随机时间触发一次更新。每次执行时：

1. 通过 AXFR/IXFR 同步已启用的官方 RPZ；
2. 对已启用的自定义 HTTPS RPZ 发起条件请求；
3. 下载发生变化的列表；
4. 检查下载结果不是 HTML 错误页面；
5. 检查 RPZ 中存在 SOA 记录；
6. 验证成功后原子替换旧文件；
7. 所有更新完成后统一重新加载 DNS。

官方列表和自定义列表共用 `/var/ipfire/dns/rpz-update.lock`，可以避免并发写入。禁用的自定义列表不会执行在线检查或下载。

如果下载失败、服务器返回错误内容或 RPZ 验证失败，现有的有效规则文件会被保留，不会因为一次更新故障导致 DNS 防火墙规则丢失。

## 安装前准备

目前安装脚本只接受以下版本：

```text
IPFire 2.29 Core Update 203
```

可以先查看当前 Core 版本：

```sh
cat /opt/pakfire/db/core/mine
```

建议在安装前备份系统配置。安装脚本自身也会备份即将修改的 CGI、更新程序、语言文件和现有自定义配置。

## 下载与校验

下载文件：

```text
ipfire-dns-firewall-custom-lists-1.1.2.zip
```

SHA-256：

```text
9d367a231e9e9c3f90204685d600731ee6e707bd2d5f9a4bb35f30ef3e13f098
```

Linux 或 IPFire 上可以这样校验：

```sh
sha256sum ipfire-dns-firewall-custom-lists-1.1.2.zip
```

macOS 可以使用：

```sh
shasum -a 256 ipfire-dns-firewall-custom-lists-1.1.2.zip
```

请将上面的文件名制作成博客下载链接，或在这里补充实际下载地址。

## 安装方法

将 ZIP 上传到 IPFire，然后以 root 身份执行：

```sh
unzip ipfire-dns-firewall-custom-lists-1.1.2.zip
cd ipfire-dns-firewall-custom-lists-1.1.2
./install.sh
```

安装程序会执行以下操作：

1. 检查 Core Update 版本和必要命令；
2. 检查 Perl CGI、语言维护脚本和 Bash 更新脚本的语法；
3. 创建带时间戳的安装前备份；
4. 保存可供卸载使用的原始官方文件；
5. 安装 WebGUI 和统一更新程序；
6. 安装英文、简体中文翻译并重建语言缓存；
7. 创建互斥锁并重新加载 DNS。

备份目录类似：

```text
/root/dns-firewall-custom-lists-backup-20260812-083836/
```

安装完成后打开：

```text
https://<IPFire地址>:444/cgi-bin/dnsbl.cgi
```

## 添加 OISD 示例

在“服务 → DNS 防火墙”中点击列表下方的“添加”，填写：

```text
名称：OISD
RPZ URL：https://big.oisd.nl/rpz
说明：OISD Big blocklist
许可证：https://github.com/sjhgvr/oisd/blob/main/LICENSE
```

保存后，新列表默认启用并在后台进行首次下载。第一次下载完成前，现有 DNS 数据不会受到影响。

回到主列表后可以：

- 通过复选框启用或停用列表，然后点击“保存”；
- 点击铅笔图标编辑自定义列表；
- 点击铅笔图标右侧的垃圾桶图标删除自定义列表；
- 在编辑页面设置应用该分类的网络区域、主机或子网。

删除操作会清理自定义配置、RPZ 文件以及该源保存的 HTTP 缓存标识。官方列表不会显示删除图标。

## 手动检查更新

WebGUI 保存列表状态时会触发相应配置更新。需要手动执行完整 RPZ 同步时，可以运行：

```sh
/usr/local/bin/dnsctrl sync-rpzs
```

查看更新日志：

```sh
grep update-rpzs /var/log/messages
```

如果源文件没有变化，日志中应能看到与 `304 Not Modified` 对应的未更新结果；此时不会重新下载整个 RPZ 文件。

## 验证拦截是否生效

先从列表提供者的 RPZ 中选择一个确认存在的测试域名，再向 IPFire DNS 查询：

```sh
dig @127.0.0.1 test-domain.example A
```

启用相应列表并完成同步后，命中的域名通常会返回 `NXDOMAIN`。随后取消勾选该列表并点击“保存”，再次查询时应恢复正常解析。

同时应检查普通域名，避免把 DNS 服务本身的故障误认为列表拦截：

```sh
dig @127.0.0.1 ipfire.org A
```

## 本版本实测结果

本扩展在 IPFire 2.29 x86_64 Core Update 203 上完成了以下测试：

- ZIP 安装和卸载；
- 卸载后重新安装；
- 添加、编辑和删除自定义列表；
- 启用和停用后实际 DNS 规则变化；
- 自定义列表命中时返回 `NXDOMAIN`；
- 普通域名保持正常解析；
- 官方与自定义更新使用同一把互斥锁；
- HTTPS RPZ 首次完整下载；
- `ETag`、`Last-Modified` 和 HTTP 304 条件更新；
- 下载失败时保留已有规则；
- 拒绝 HTML 页面和缺少 SOA 的无效内容；
- RPZ 文件原子替换；
- 英文和简体中文 WebGUI；
- 添加页和编辑页空字段直接返回；
- 安装包内部 SHA-256 校验及隐藏文件检查。

测试使用的 OISD RPZ 包含约 50.2 万条拦截记录。启用时，选定测试域名返回 `NXDOMAIN`；停用时恢复正常解析。HTTP 缓存标识未变化时，更新检查返回 304，不再重复下载约 14 MB 的完整列表。

## 卸载方法

进入之前解压的目录，运行：

```sh
./uninstall.sh
```

卸载程序将：

- 恢复首次安装时保存的官方 `dnsbl.cgi`；
- 恢复官方 `update-rpzs`；
- 移除扩展添加的语言条目；
- 从当前 DNS 配置中移除自定义 RPZ；
- 删除扩展锁文件和遗留的独立更新任务；
- 重新加载 DNS。

自定义配置和 RPZ 文件会先备份到：

```text
/root/dns-firewall-custom-lists-uninstall-<时间戳>/
```

如果卸载程序找不到安装时保存的官方基线文件，它会拒绝执行不完整的恢复，避免把系统留在半卸载状态。

## 重要说明

- 这是非官方社区扩展，仅建议在充分备份后测试；
- 当前只在 IPFire 2.29 Core Update 203 上验证；
- IPFire Core Update 可能覆盖本扩展修改的文件，升级后需重新确认兼容性；
- 不要添加来源不明的 RPZ；
- 第三方列表的内容、服务可用性和许可证由列表提供者负责；
- 大型 RPZ 会占用一定内存和存储空间，即使条件请求减少了重复下载，也应关注设备资源；
- 对外发布时建议同时提供 ZIP 的 SHA-256 校验值。

## 涉及的主要文件

```text
/srv/web/ipfire/cgi-bin/dnsbl.cgi
/usr/local/bin/update-rpzs
/var/ipfire/dns/custom_dnsbl.json
/var/ipfire/dns/rpz-update.lock
/var/ipfire/dns/custom-lists-original/
```

自定义列表配置保存在 `/var/ipfire/dns/custom_dnsbl.json`，与官方 `/var/ipfire/dns/dnsbl.json` 分离，因此不会被官方列表元数据更新覆盖。

## 结语

这个扩展的目标不是替代 IPFire 官方 DNS 防火墙，而是在保留官方 RPZ、访问控制和更新入口的基础上，为有需要的用户增加第三方 HTTPS RPZ 管理能力。

通过统一更新入口、互斥锁、条件 HTTP 请求、内容验证和原子替换，自定义列表既可以在 WebGUI 中方便管理，也尽量避免每小时重复下载和更新失败破坏现有规则。

欢迎在 IPFire 社区反馈兼容性、测试结果和改进建议。
