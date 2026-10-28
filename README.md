<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# IPFire Community Repository

> **适配 Core 204 版本**

正式下载目录每个插件只保留最新版。升级前请备份配置并保留 `/opt/ipfrepo/cache/`：旧版卸载依赖缓存的旧安装包；缓存缺失时应先升级到最新版再卸载。历史包可从 Git 历史恢复。

<p align="center">

**适用于 IPFire 2.29 Core Update 204（x86_64）的非官方社区插件仓库**

![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Core Update](https://img.shields.io/badge/Core_Update-204-red)
![Architecture](https://img.shields.io/badge/x86__64-Supported-blue)
![Community](https://img.shields.io/badge/Community-Maintained-brightgreen)
![SHA256](https://img.shields.io/badge/Integrity-SHA256-success)

</p>

## 项目特色

- 独立于官方 Pakfire
- 所有软件包安装前均进行 SHA-256 校验
- 使用 `ipfrepo` 统一管理安装、升级与卸载
- 不修改官方仓库及系统信任链
- 社区维护，持续扩展插件生态
- 所有当前插件均已在 IPFire 2.29 Core Update 204 实机完成安装、语法及卸载恢复验证

## 安装仓库

在终端环境，以 `root` 身份执行：

```bash
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh | sh
```
## 安装插件
```bash
ipfrepo update
ipfrepo install mihomo
```

## 常用命令

```bash
ipfrepo list                       # 列表插件
ipfrepo info <package>             # 查看插件
ipfrepo install <package>          # 安装插件
ipfrepo remove <package>           # 移除插件
ipfrepo update                     # 更新仓库元数据
ipfrepo upgrade                    # 升级已安装插件
```

## 插件列表

| 名称 | 版本 | 说明 |
| --- | --- | --- |
| `adguardhome` | 1.0.4 | AdGuard Home DNS 过滤与管理工具 |
| `backup` | 1.0.3 | 防火墙配置备份管理 |
| `captive-enhanced` | 1.1.10 | 多语言强制门户、上网劵、手动客户端授权及 PDF 导出 |
| `dns-firewall-custom-lists` | 1.1.3 | DNS 防火墙自定义 HTTPS RPZ 列表管理 |
| `easytier` | 1.0.0 | [EasyTier 私有组网、WAN 放行、LAN 转发与可选 NAT](docs/easytier/README.md) |
| `ipfire-dyndns` | 1.0.3 | Cloudflare、阿里云和腾讯云 DDNS 补丁 |
| `lang` | 1.0.4 | 中文本地化更新工具 |
| `lucky` | 1.0.4 | Lucky 网络工具箱 |
| `mihomo` | 1.0.4 | Mihomo 代理与透明代理管理 |
| `reports` | 1.0.6 | 防火墙、IDS、URL Filter 和 DNS Firewall 报告 |
| `sing-box` | 1.0.4 | sing-box 代理服务 |
| `speedtest` | 1.0.4 | 互联网测速 |
| `syncthing` | 1.0.4 | Syncthing 文件同步服务 |
| `tailscale` | 1.0.4 | Tailscale VPN 集成 |
| `ttyd` | 1.0.4 | ttyd 网页终端 |
| `zerotier` | 1.0.4 | ZeroTier VPN 集成 |


## 组件版本

本次软件包内置或安装使用的上游版本：

| 组件 | 版本 | 获取方式 |
| --- | --- | --- |
| Mihomo | 1.19.33 | 软件包内置 |
| sing-box | 1.14.4 | 软件包内置（glibc amd64） |
| AdGuard Home | 0.107.79 | 软件包内置 |
| Lucky | 2.27.2 | 软件包内置 |
| Syncthing | 2.1.7 | 软件包内置 |
| Tailscale | 1.104.2 | 软件包内置 |
| Speedtest Go | 1.8.3 | 软件包内置 |
| ttyd | 1.7.7 | 软件包内置 |
| ZeroTier | 1.16.2 | 软件包内置 |

## 仓库结构

```text
.
├── src/                # 插件源码
├── repo/
│   └── x86_64/All/     # 发布软件包
├── install-repo.sh     # 安装脚本
└── README.md
```

## 免责声明

本项目为社区维护项目，插件大多为借助AI编写，或来源于社区提供，无 IPFire 官方技术支持。安装前，请务必备份配置，并建议优先在测试环境验证。
