<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# ZeroTier for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> 插件版本：**1.0.5** · 适用系统：**IPFire 2.29 Core Update 206（x86_64）**

本项目为 IPFire WebUI 添加了一个 ZeroTier VPN 管理页面。

![](image/zerotier.cn.png)

## 安装插件

在 IPFire 系统中以 `root` 用户执行：

```sh
bash install.sh
```

安装完成后，打开 IPFire Web 管理界面，进入：

```text
服务（Services） > ZeroTier VPN
```

## 卸载插件

```sh
bash uninstall.sh
```

## 配置文件

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

## 加入网络

1. 点击 启动
2. 输入 Network ID
3. 点击 保存
4. 点击 加入
5. 登录 ZeroTier 控制台，对该节点进行授权（Authorize）

完成授权后，设备即可加入 ZeroTier 网络。

## 免责声明

这是一个非官方社区项目，与 IPFire 团队没有任何关联，自行承担使用过程中可能产生的风险。
