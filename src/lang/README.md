# IPFire 汉化补丁 1.0.7

Core 206 改用 GNU gettext，原来的 `langs/zh.pl`、`addon-lang/*.zh.pl` 和语言缓存更新程序不再用于系统页面。本插件识别实际语言后端：旧版继续下载和安装原来的 ZIP，gettext 系统从页面保存的地址下载新版 IPFire_lang.zip，读取简繁 JSON 词库并合并安装。旧格式 ZIP 会被明确拒绝。

`src/usr/local/share/ipfire-lang/zh_CN.json` 及 `zh_TW.json` 是可审阅的补充翻译。安装时合并到设备现有 `/usr/share/locale/zh_CN/LC_MESSAGES/ipfire.mo`，保留原有上下文、复数和元数据，校验后原子替换。首次安装保留 `ipfire.mo.before-community-zh`。国家/地区译名依据 Babel 的 CLDR 简体中文地区数据，并补充旧代码和特殊区域。

`core206-compat.json` 为没有经过 gettext 的显示标签补充翻译调用，并修复 EasyTier/Mihomo 对 `zh_CN`、`zh-CN` 等语言代码的识别。仅匹配已知源码片段；未知版本报错，不猜测替换。每个修改过的文件旁保留 `.before-community-zh` 备份，替换前运行 Perl 语法检查。适配这些文件需要其所属插件已安装；未安装的文件跳过。

安装：以 root 执行 `bash install.sh`，再在“系统 > 汉化补丁”中点击“立即汉化”。Core 206 请先上传新版 IPFire_lang.zip，然后在插件页面保存其 HTTPS 直接下载地址（目前限定 cloud.pfchina.org）。插件不执行下载包中的脚本，不直接覆盖下载包提供的任意路径。繁体中文补充词库 `zh_TW.json` 与简体词库同步提供 532 项补充（含六项菜单名称），使用繁体用语并保留已有上游译文；安装日志也按界面语言显示。上游系统更新可能覆盖词库及显示适配，需要重新安装；如源码变更，先重新核对匹配片段。

本机 2026-11-25 验证：简繁词库各 532 个补充条目，设备词库各 2589 项；2142 个静态 gettext 字符串无缺失；74 个菜单入口生成中文页面，无超时。PPP 设置页因 RED 接口非 PPPoE 正常输出中文限制说明并以状态 1 退出。验证包括 Web 用户 nobody 的 sudo 安装路径、页面输出、Perl 语法及 GNU msgfmt 检查；没有遍历所有表单操作、错误分支或浏览器交互。协议名、产品名、用户配置值和原始诊断日志保留原文。

恢复：以 root 将 `/usr/share/locale/zh_CN/LC_MESSAGES/ipfire.mo.before-community-zh` 复制回 `ipfire.mo`，按需将各文件旁的 `.before-community-zh` 备份恢复到原路径。只在设备文件仍对应本次版本时恢复；系统或插件更新后不要盲目覆盖。卸载脚本只删除安装入口和辅助文件，保留词库及备份，和此前版本的补丁保留行为一致。

远程下载会为分享链接和每次重定向后的文件链接附加请求时间参数，以避开 Cloudflare 缓存的旧版同名文件；页面保存的原始 URL 不变。
