# Reports for IPFire

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Reports](https://img.shields.io/badge/Reports-WebUI-blue)

本项目将 Reports 集成到 IPFire WebUI 中，用于生成和查看防火墙、IDS、URL Filter、DNS Firewall 等报告。

## 功能

- IPFire WebUI 菜单集成
- 防火墙报告
- IDS 报告
- URL Filter 报告
- DNS Firewall 报告
- 按小时、每日、每周、每月执行的计划任务
- 多语言文件集成

## 安装命令

以 root 用户登录终端，在项目目录中运行：

```bash
bash install.sh
```

## 卸载命令

以 root 用户登录终端，在项目目录中运行：

```bash
bash uninstall.sh
```

## 访问

安装完成后，在 IPFire WebUI 中访问：

```text
服务 > Reports
```

## 目录结构

```text
src/
install.sh
uninstall.sh
```

安装脚本会将 `src/` 下的文件复制到 IPFire 系统根目录，并设置 CGI、计划任务、报告目录和语言文件所需的权限。
