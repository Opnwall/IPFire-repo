<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# sing-box for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> 插件版本：**1.0.5** · 适用系统：**IPFire 2.29 Core Update 206（x86_64）**

sing-box 是一款性能优秀的开源网络代理平台，支持多种主流代理协议。它基于现代化架构设计，具备高性能、低资源占用和灵活配置等特点，可用于网络代理、流量分流、负载均衡以及安全访问等场景。

本插件将 sing-box 无缝集成到 IPFire WebUI，支持透明代理，并提供配置编辑、服务管理、状态监控和日志查看等功能，使用户能够通过图形界面轻松管理 sing-box。

## 集成程序

[sing-box](https://github.com/SagerNet/sing-box/releases)

## 注意事项

1. 当前仅支持x86_64 平台。
2. 脚本集成了可用的默认设置，参照修改节点信息即可使用。
3. 为减少长期运行保存的日志数量，在调试完成后，请将日志层级修改为error。

## 安装插件

以 root 用户登录终端，运行以下命令安装：

```bash
bash install.sh
```
## 卸载插件

以 root 用户登录终端，运行以下命令卸载：

```bash
bash uninstall.sh
```

## 配置过程

1. 安装完成，导航到 服务>Sing-Box 菜单，修改配置并保存。
2. 点击启动按钮，根据输出的日志内容，排除配置文件错误。
3. 正常启动后，客户端访问 ip111.cn，检查分流是否正常。

## 其他事项

1. 脚本具备开机自启功能。
2. 默认配置文件开启了 api 功能，访问 http://lan_ip:9090/ui 登录仪表盘。

## 免责声明

这是一个非官方社区项目，与 IPFire 团队没有任何关联，自行承担使用过程中可能产生的风险。
