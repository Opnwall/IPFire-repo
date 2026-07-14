# IPFire Community Repository

**IPFire 2.29 x86_64** 的非官方社区插件仓库。它使用独立的 `opnwall` 管理器，不替换、不修改 IPFire 官方 Pakfire 仓库及其 GPG 信任链。

## 安装仓库

以 `root` 身份执行：

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-opnwall.sh | sh
```

## 使用方法

```sh
opnwall list
opnwall info adguardhome
opnwall install adguardhome
opnwall remove adguardhome
opnwall update
opnwall upgrade
```

每个插件在下载后都会先验证 SHA-256，再调用项目自带的安装或卸载脚本。状态保存在 `/opt/opnwall/`。

## 插件列表

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

## 源码

完整项目源码位于 [`src/`](src/)；发布包位于 [`repo/x86_64/All/`](repo/x86_64/All/)。

## 免责声明

本仓库与 IPFire 项目没有隶属关系，也不受其官方支持。第三方插件可能修改防火墙、DNS、代理或系统服务。安装前请备份配置并优先在非生产环境测试。
