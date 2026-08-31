# Reports for IPFire

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Core Update](https://img.shields.io/badge/Core_Update-203-red)
![Reports](https://img.shields.io/badge/Reports-WebUI-blue)

本项目将 Reports 集成到 IPFire WebUI 中，用于生成和查看防火墙、IDS、URL Filter、DNS Firewall 等报告。

## 功能

- IPFire WebUI“服务”菜单集成
- 防火墙报告
- IDS 报告
- URL Filter 报告
- DNS Firewall 报告
- 响应式 HTML 报告、SVG 统计图表和邮件安全版报告正文
- 防火墙攻击模式、IDS 严重级别、URL 分类和 DNS 防火墙列表统计
- 按小时、每日、每周、每月执行的计划任务
- 多语言文件集成，包含适配 IPFire `LANGUAGE=zh` 的完整简体中文报告翻译

当前版本基于 `reports.ipfire` 2026-08-31 源码更新，并在 IPFire 2.29 Core Update 203（x86_64）上完成安装和报告生成测试。

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
