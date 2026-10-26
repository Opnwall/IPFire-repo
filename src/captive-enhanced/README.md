<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>


# IPFire Captive Portal Enhanced

面向 IPFire 的社区版强制门户增强插件，提供中文界面、多语言访客认证、上网劵、手动客户端授权、品牌徽标、条款展示及中文 PDF 导出。

> 当前版本：**1.1.9**  
> 已验证环境：**IPFire 2.29 Core Update 203，x86_64**  
> 本项目由社区维护，不代表 IPFire 官方认证。其他 Core 版本请先在测试环境验证。

![门户设置](image/setting1.png)

## 主要功能

- 支持“条款与条件”和“上网劵”两种访客认证方式。
- 管理员可按 IP、MAC 和时长直接添加客户端，不消耗上网劵。
- 访客认证页支持 11 种语言，可跟随浏览器语言或手动切换。
- 管理页面跟随 IPFire GUI 语言，上网劵及 PDF 可独立选择语言。
- 支持上传 PNG/JPEG 品牌徽标，最大 2 MiB，并提供即时预览。
- 单一“条款与条件”编辑框，访客页以可折叠区域显示。
- 使用安全随机源生成 16 位十六进制上网劵号码。
- PDF 支持简繁中文、拉丁扩展和西里尔文字，每页最多 8 张访问劵。
- 客户端联网探测认证成功后跳转至 `https://www.bing.com/`，普通网址仍恢复原始目标。
- 使用 IPFire 原生 `captivectrl` 和 `wirelessctrl` 应用规则，不安装额外守护进程。
- 安装、升级和回退均自动保存快照。

## 界面预览

| 设置页面 | 上网劵管理 |
|---|---|
| ![设置页面](image/setting1.png) | ![上网劵页面](image/Coupon.png) |

| 条款认证 | PDF 导出 |
|---|---|
| ![条款认证](<image/Terms & Conditions.png>) | ![PDF 导出](image/Coupon_pdf.png) |

## 认证方式

| 功能 | 说明 |
|---|---|
| 条款与条件 | 访客同意条款后获得授权，时长由管理页面设置。 |
| 上网劵 | 访客输入有效且未使用的劵码后获得授权，使用生成该劵时配置的时长。 |
| 添加客户端 | 管理员直接授权指定 IP 和 MAC，可在以上两种访问类型下使用。 |

上网劵兑换和手动添加客户端最终都会写入同一客户端授权列表。上网劵为一次性使用，兑换成功后立即从未使用列表移除。

## 网络接口行为

- 安装或升级时自动读取目标设备网络配置。
- 存在 GREEN 接口时默认设置 `ENABLE_GREEN=on`。
- 存在 BLUE 接口时默认设置 `ENABLE_BLUE=on`。
- 不存在的内部区域保持 `off`，RED 不会作为强制门户接口启用。
- 管理页面可手动启停 GREEN/BLUE；旧页面提交不会意外覆盖当前状态。
- 仅允许已启用 GREEN/BLUE 网段内的客户端，排除网关、网络地址和广播地址。

强制门户只负责认证和访问控制，不提供同一二层网络内的客户端隔离。酒店、访客 Wi-Fi 等场景仍应通过 AP 客户端隔离或 VLAN 阻止访客之间互访。

## 系统要求

- IPFire 2.29；本版本已在 Core Update 203 x86_64 上验证。
- 系统原生 Captive Portal 已安装，并存在 `/usr/local/bin/captivectrl` 和 `/etc/httpd/conf/vhosts.d/captive.conf`。
- Perl 模块：`CGI`、`HTML::Template`、`PDF::API2`、`File::LibMagic`、`JSON::PP`、`Digest::SHA`。
- Bash、`flock`、`tar`、Apache 管理命令及 `/usr/local/bin/update-lang-cache`。

## 安装

将完整项目目录复制到 IPFire，以 `root` 执行：

```bash
cd captive-enhanced
bash install.sh
```

安装器会检查平台和语法、备份现有程序及门户数据、安装文件、迁移旧数据、更新语言缓存、检查 Apache 配置，并重新加载门户规则。安装失败时会尝试自动恢复本次快照。

最新备份路径保存在：

```text
/var/ipfire/captive-enhanced/last-backup
```

备份目录格式：

```text
/var/backups/captive-enhanced/<日期时间>-<PID>/
```

## 管理入口

设置页面：

```text
https://IPFire地址:444/cgi-bin/captive.cgi
```
## 基本使用

### 条款与条件

1. 勾选需要启用的 GREEN/BLUE。
2. 将访问类型设为“条款与条件”。
3. 选择会话时长。
4. 填写欢迎标题、SSID、公司和条款。
5. 保存后使用未授权客户端接入对应网络测试。

### 上网劵

1. 将访问类型设为“上网劵”并保存。
2. 在“生成上网劵”区域选择时长和数量，按需填写备注。
3. 生成后可查看、删除或导出 PDF。
4. 访客输入未使用的劵码后获得网络访问权限。

### 添加客户端

填写客户端 MAC、IP、允许时长和备注后提交。IP 必须属于已启用的 GREEN/BLUE 网段，MAC 必须为有效单播地址。该功能是管理员直接授权，不要求预先生成或消耗上网劵。

在勾选启用前，必须先给管理电脑添加一条无限制的上网劵，以防止锁住自己。

## 上网劵 PDF

- 使用捆绑的 Captive Sans CJK 字体，许可证为 SIL Open Font License 1.1。
- 每页最多 8 张访问劵。
- 标题、公司、SSID、劵码、时长和备注按卡片宽度排版。
- 长劵码会完整换行，不截断。
- 为兼容 IPFire 上的 PDF::API2 2.033，字体采用完整嵌入，典型 PDF 约为 6 MiB。

![PDF 示例](image/Coupon_pdf.png)

## 徽标上传

- 支持 PNG 和 JPEG，最大 2,097,152 字节。
- 浏览器选择图片后立即预览，保存后才写入系统。
- 无效格式或超限文件不会替换当前徽标。
- 文件选择按钮和空状态提示跟随 IPFire GUI 语言，而不是操作系统语言。

## 升级与数据迁移

升级使用与首次安装相同的命令：

```bash
bash install.sh
```

安装器会保留现有设置、未使用劵码、客户端授权、徽标和条款，并在覆盖前创建新快照。

旧版本若存在第二份条款 `terms2.txt`，升级时会以两个换行符分隔追加到 `terms.txt`，然后清空旧文件。管理页和访客页统一使用一份“条款与条件”。该迁移可重复执行，不会再次追加已迁移内容。

IPFire Core 更新可能覆盖 CGI、清理程序或 Apache 配置。Core 更新前应保留系统及插件备份；更新后重新检查兼容性并安装适配版本。

## 回退

恢复最近一次安装前的状态：

```bash
bash uninstall.sh
```

恢复指定快照：

```bash
bash uninstall.sh /var/backups/captive-enhanced/<日期时间>-<PID>
```

回退会恢复当时的程序和 Captive Portal 数据，并重新加载 Apache 及门户规则。回退前，脚本会将当前门户数据另存为 `before-restore-*.tar.gz`。

## 测试

当前基础检查结果：

- 安全及状态测试：82 项通过。
- 语言资源测试：43 项通过。
- Logo 前端状态测试：10 项通过。
- GREEN、GREEN+BLUE 及缺少旧配置键三种安装场景通过。
- 已在真实 Core 203 主机验证安装、回退、条款认证、上网劵兑换、手动客户端授权、Windows 跳转和中文 PDF。

BLUE/AP、跨 Core 版本和不同硬件平台仍应在对应设备上单独验收。

## 安全设计

- 管理修改仅接受 POST，并验证绑定管理员、来源 IP 和有效期的 HMAC 表单令牌。
- 访客地址只使用 Apache `REMOTE_ADDR`，不信任转发头。
- 上网劵兑换会核对客户端 IP 所在接口及 ARP 表中的 MAC。
- 每个访客 IP 每 10 分钟最多提交 10 次认证请求。
- 设置、劵码和客户端记录使用共享锁及原子替换，避免并发写入产生半文件。
- 单次兑换使用事务日志，进程中断后可在下一次加锁时恢复。
- 规则添加、撤销及到期清理均交由 IPFire 原生控制器处理。

这些机制不能替代磁盘备份，也不承诺突然断电或存储损坏时的事务持久性。

## 项目结构

```text
captive-enhanced/
├── install.sh                 # 安装及升级
├── uninstall.sh               # 回退
├── src/                       # 安装到 IPFire 的文件
├── tests/                     # 安全、语言、CGI、前端和接口测试
├── image/                     # README 截图
├── Manuale captive-zh-CN.md   # 中文详细手册
├── Manuale captive-en.md      # 英文详细手册
├── MANIFEST.sha256            # 安装文件校验清单
└── VERSION
```

## 已知限制

- 当前完整实机验证基于 IPFire 2.29 Core Update 203 x86_64。
- Captive Portal 不能隔离同一二层网络中的访客设备。
- 管理员填写的欢迎标题、公司和条款正文不会自动翻译。
- 捆绑字体不能保证覆盖所有 Unicode 字符或复杂文字排版。
- 匿名 PDF 导出地址可被所有能够访问该管理地址的用户读取。

## 许可证与致谢

程序遵循 GPL-3.0-or-later，并保留 IPFire 及原社区作者的版权声明。

捆绑字体基于 Noto Sans SC 与 Noto Sans，采用 SIL Open Font License 1.1；许可证和修改说明位于 `src/usr/share/fonts/captive-enhanced/`。

感谢 IPFire 项目、原稿作者 **tratru** 及所有参与测试和反馈的用户。

## 参考

- [IPFire Captive Portal 官方文档](https://www.ipfire.org/docs/configuration/network/captive)
- [IPFire 官方网站](https://www.ipfire.org/)
