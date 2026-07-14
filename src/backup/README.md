# Backup for IPFire

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Firewall Backup](https://img.shields.io/badge/Firewall%20Backup-WebUI-blue)

本项目将防火墙配置备份功能集成到 IPFire WebUI 中，用于创建、恢复、下载和删除防火墙规则备份。

## 功能

- IPFire WebUI 菜单集成
- 创建防火墙配置备份
- 恢复已有备份
- 下载备份
- 删除备份
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
服务 > Firewall Backup
```

## 目录结构

```text
src/
install.sh
uninstall.sh
```

安装脚本会将 `src/` 下的文件复制到 IPFire 系统根目录，并设置 CGI、菜单、语言文件和备份目录所需的权限。
