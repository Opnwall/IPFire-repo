<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Localization Patch for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> 插件版本：**1.0.8** · 适用系统：**IPFire 2.29 Core Update 206（x86_64）**

本插件面向 Core 206 的 GNU gettext 机制，从页面保存的下载地址获取新版 `IPFire_lang.zip`，读取简繁 JSON 词库并合并安装。系统页面不再使用旧的 `langs/zh.pl`、`addon-lang/*.zh.pl` 和语言缓存更新程序。

## 翻译文件

`src/usr/local/share/ipfire-lang/zh_CN.json` 和 `zh_TW.json` 是可审阅的补充翻译。安装时合并到对应语言的 `/usr/share/locale/<语言>/LC_MESSAGES/ipfire.mo`，保留原有上下文、复数和元数据，校验后原子替换。首次安装保留 `ipfire.mo.before-community-zh`。

国家和地区译名依据 Babel 的 CLDR 简体中文地区数据，并补充旧代码和特殊区域。

## 安装插件

在完整插件目录中，以 root 执行：

```sh
bash install.sh
```

## 使用

1. 将新版 `IPFire_lang.zip` 上传到云盘。
2. 打开 **系统 > 汉化补丁**。
3. 保存汉化包的 HTTPS 直接下载地址，目前限定 `cloud.pfchina.org`。
4. 点击“立即汉化”，检查安装日志。

## 注意事项

- 插件不执行下载包中的脚本，不直接覆盖下载包提供的任意路径。
- 上游系统更新可能覆盖词库及显示适配，需要重新安装。
- 如系统源码变更，应先重新核对显示适配的匹配片段。

## 免责声明

这是社区维护的非官方项目，与 IPFire 团队没有隶属关系。使用者需自行评估并承担使用风险。
