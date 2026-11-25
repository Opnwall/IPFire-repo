<div align="center">
  <a href="README.md">English</a> |
  <a href="README.CN.md">中文</a>
</div>

# IPFire 的 ZeroTier 插件

> 插件版本：**1.0.5** · 适用系统：**IPFire 2.29 Core Update 206（x86_64）**
> 界面语言：English / 简体中文 / 繁體中文；识别 Core 206 的语言代码。

2026-11-25 验证：本轮通过 Core 206 x86_64 的语法、翻译资源和英、简、繁初始页面隔离检查；未在本轮执行该服务的真实联网、重启及完整安装卸载回归。

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Architecture](https://img.shields.io/badge/Arch-x86__64-blue)
![License](https://img.shields.io/badge/License-GPLv3-green)

本项目为 IPFire WebUI 添加了一个 ZeroTier VPN 管理页面。CGI 页面直接内嵌了英文、简体中文和繁体中文语言包。

![](image/zerotier.cn.png)

## 安装

在 IPFire 系统中以 `root` 用户执行：

```sh
bash install.sh
```

安装完成后，打开 IPFire Web 管理界面，进入：

```text
服务（Services） > ZeroTier VPN
```

## 卸载

```sh
bash uninstall.sh
```

## 配置

默认配置文件安装在：

```text
/var/ipfire/zerotier/settings
```

其中：

```text
ALLOW_DEFAULT=on
```

表示允许使用 ZeroTier 管理的默认路由。

除非你明确希望通过 ZeroTier 网络提供默认路由（即让所有互联网流量经过 ZeroTier 网络），否则建议保持关闭状态。

## 配置

1. 点击 启动
2. 输入 Network ID
3. 点击 保存
4. 点击 加入
5. 登录 ZeroTier 控制台，对该节点进行授权（Authorize）

完成授权后，设备即可加入 ZeroTier 网络。

## 免责
这是一个非官方社区项目，与 IPFire 团队没有任何关联，自行承担使用过程中可能产生的风险。
