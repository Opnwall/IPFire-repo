# IPFire Community Repository

<p align="center">

**适用于 IPFire-2.29  x86_64 的非官方社区插件仓库**

提供独立的软件仓库与 `ipfrepo` 包管理器，不替换、不修改官方 Pakfire 仓库及其 GPG 信任链。

![IPFire](https://img.shields.io/badge/IPFire-orange)
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

# 安装仓库

在终端环境，以 `root` 身份执行：

```bash
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh | sh
```
# 安装插件
```bash
ipfrepo update
ipfrepo install mihomo
```

# 常用命令

```bash
ipfrepo list
ipfrepo info <package>
ipfrepo install <package>
ipfrepo remove <package>
ipfrepo update
ipfrepo upgrade
```

# 插件列表

| 名称 | 版本 | 说明 |
| --- | --- | --- |
| `adguardhome` | 1.0.1 | AdGuard Home DNS 过滤与管理界面 |
| `backup` | 1.0.1 | 防火墙配置备份管理页面 |
| `ipfire-dyndns` | 1.0.1 | Cloudflare、阿里云和腾讯云 DDNS 补丁 |
| `lang` | 1.0.1 | 中文本地化更新工具 |
| `lucky` | 1.0.1 | Lucky 网络工具箱 |
| `mihomo` | 1.0.1 | Mihomo 代理与透明代理管理 |
| `reports` | 1.0.1 | 防火墙、IDS 和 DNS 报告 |
| `sing-box` | 1.0.1 | sing-box 代理服务 |
| `syncthing` | 1.0.1 | Syncthing 文件同步服务 |
| `tailscale` | 1.0.1 | Tailscale VPN 集成 |
| `ttyd` | 1.0.1 | ttyd 网页终端 |
| `zerotier` | 1.0.1 | ZeroTier VPN 集成 |

# 仓库结构

```text
.
├── src/                # 插件源码
├── repo/
│   └── x86_64/All/     # 发布软件包
├── install-repo.sh     # 安装脚本
└── README.md
```

# 免责声明

本项目为社区维护项目，无 IPFire 官方技术支持。安装前，请务必备份配置，并建议优先在测试环境验证。

