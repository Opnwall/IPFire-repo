# Core 204 二进制版本

核实日期：2026-10-27。面向 Linux x86_64，版本与来源在本轮适配时核实；以下内容对应 Core 204 发布包。

| 组件 | 原版本 | 当前候选 | 官方来源 |
|---|---|---|---|
| Mihomo | 1.19.29 | 1.19.33（amd64-v1） | [Release](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.33) |
| sing-box | 1.13.14 | 1.14.4（glibc amd64） | [Release](https://github.com/SagerNet/sing-box/releases/tag/v1.14.4) |
| AdGuard Home | 0.107.78 | 0.107.79 | [Release](https://github.com/AdguardTeam/AdGuardHome/releases/tag/v0.107.79) |
| Lucky | 2.27.2 | 2.27.2（已是最新） | [Release](https://github.com/gdy666/lucky/releases/tag/v2.27.2) |
| Syncthing | 安装时动态下载 | 2.1.7（现已捆绑） | [Release](https://github.com/syncthing/syncthing/releases/tag/v2.1.7) |
| Tailscale | 安装时动态下载 | 1.104.2（现已捆绑 CLI 和 daemon） | [官方稳定仓库](https://pkgs.tailscale.com/stable/) |
| Speedtest Go | 1.7.10 | 1.8.3 | [Release](https://github.com/showwin/speedtest-go/releases/tag/v1.8.3) |
| ttyd | 1.7.7 | 1.7.7（已是最新） | [Release](https://github.com/tsl0922/ttyd/releases/tag/1.7.7) |
| ZeroTier | 1.16.2 | 1.16.2（已是最新，保留原构建） | [Release](https://github.com/zerotier/ZeroTierOne/releases/tag/1.16.2) |

## 下载归档 SHA-256

前六个 GitHub 归档对照官方 Release API 的 asset digest 验证；ttyd 对照官方 SHA256SUMS；Tailscale 对照官方 `.tgz.sha256`。这是上游摘要验证，不宣称已做独立签名验证。

```text
8ec92e7b2fdc6b853ba00156bab7e4e965c8b0d843b8c4ac8ab98795f02ad524  mihomo-linux-amd64-v1-v1.19.33.gz
231e57c18378f780a08de832844a1ca9716e17a7bcf82964b350844d243c03ac  sing-box-1.14.4-linux-amd64-glibc.tar.gz
c48f4a43000665484c5ec28177de11a004759b620dae8f77b2aabefc9ef3687f  AdGuardHome_linux_amd64.tar.gz
78adf3fa5e8869be0b1510cb7bcc755d57dccb13252989c8394a7207a392fe66  lucky_2.27.2_Linux_x86_64.tar.gz
2edc416e7ed136b7c858ed5f3f02a3b8316589605e54c380228ceea7acbf0142  syncthing-linux-amd64-v2.1.7.tar.gz
c55caae22927cd719a2f8c0bef96ecf74b5fe8ca919ff9200d76328ae5de9477  speedtest-go_1.8.3_Linux_x86_64.tar.gz
8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55  ttyd.x86_64
512f613ed7d04fc7282f7dc5bd76aa105aae28168fbb9357eb749ebcbc29f0ae  tailscale_1.104.2_amd64.tgz
```

ZeroTier 最新 Release 不提供二进制资产，本地构建在目标机报告 1.16.2，与官方最新版本一致，因此没有用第三方来源替换。原二进制 SHA-256：`f1d57895144065ce963292f658f9eac4375c42013ccdf083e37124097b612334`。

## 验证范围

以上版本均已在真实 Core 204 主机进行安装、卸载、重装和页面渲染验证。新 Mihomo 和 sing-box 使用不启用 TUN、仅监听回环地址的最小配置完成实际代理请求；不代表用户所有订阅或旧版配置均兼容。Syncthing/Tailscale 加入捆绑后不再需要为该架构在每次安装时下载 latest；其他架构仍需其适配二进制。

完整验证范围及待验收事项见 [Core 204 验收报告](CORE204-VALIDATION.md)。插件包版本与上游组件版本相互独立。
