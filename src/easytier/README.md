<div align="center">
  <a href="README.md">中文</a> |
  <a href="README_US.md">English</a>
</div>

# EasyTier for IPFire

IPFire 社区 EasyTier 异地组网插件。通过 Web 界面配置网络名称、密码和对端地址，将不同位置的设备加入同一虚拟网络，并按需访问远端局域网。

本项目为社区插件，并非 IPFire 或 EasyTier 官方插件。

## 兼容性

| 项目 | 说明 |
| --- | --- |
| 插件版本 | 1.0.0 |
| 内置程序 | EasyTier 2.6.4 core / CLI |
| 已验证系统 | IPFire 2.29 Core Update 204 |
| 架构 | x86_64 |
| 管理入口 | 服务 → EasyTier |
| 界面语言 | 简体中文、繁体中文、英文，跟随 GUI 设置 |

安装器仅接受上述 Core 版本和架构，不支持将此包直接安装到 ARM 或其他 Core 版本。

## 插件功能

- 使用网络名称和密码加入私有网络，密码不回显，留空保存可保留已有密码。
- 自动或静态虚拟 IPv4、多对端连接、可选 TCP/UDP 监听端口。
- 公布本机管理的 IPv4 网段。
- 启动、停止、重启和可选开机启动。
- 可横向滚动的节点与路由表格。
- 可选 WAN 放行，同步到 IPFire 原生规则页面。
- 可选 GREEN/BLUE 与 VPN 双向转发，以及 LAN 源地址转换（NAT）。

不预置公共账号或公共中继。初次安装默认停止，开机启动、WAN 放行、LAN 转发和 NAT 均默认关闭。

## 安装方法

先备份 IPFire，虚拟机建议创建快照，并确保可以使用 SSH 或本地控制台。以下命令在 IPFire 上以 root 执行。

首次使用社区仓库时，先安装仓库客户端（建议先下载并审阅脚本）：

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh -o /tmp/install-ipfrepo.sh
sh /tmp/install-ipfrepo.sh
```

安装 EasyTier：

```sh
ipfrepo update
ipfrepo install easytier
```

已安装仓库客户端时，不必重复安装。仓库客户端会校验安装包的 SHA-256。访问 [社区仓库](https://opnwall.github.io/IPFire-repo/) 查看软件包列表。

需要离线安装时，可从仓库下载并核对安装包校验值，上传到 IPFire 后执行：

```sh
tar -xzf easytier-1.0.0-x86_64.tar.gz
cd easytier
bash install.sh
```

按提示确认后，进入 **服务 → EasyTier**。安装器拒绝覆盖非本插件管理的同名文件；升级会保留已有插件配置，但会停止服务。

## 快速配置

1. 填写与其他成员一致的网络名称和密码。
2. 填写可达对端，每行一个，例如 `tcp://vpn.example.net:11010`。
3. 保持“自动虚拟地址”开启；如需固定地址，取消该选项并填写未占用地址，例如 `10.126.0.10/24`。
4. 点击“保存”，再点击“启动”。
5. 点击“节点”和“路由”，检查连接与公布网段。
6. 确认通信和管理访问正常后，再按需开启开机启动及其他选项。

自动地址可能在重启后改变；固定访问场景应使用确认无冲突的静态地址。

## 配置说明

| 配置项 | 说明 |
| --- | --- |
| 网络名称 | 私有网络标识，各成员保持一致 |
| 网络密码 | 私有网络密码；保存时留空保留原密码 |
| 虚拟 IPv4 | 静态地址及前缀，例如 `10.126.0.10/24`；自动模式留空 |
| 监听端口 | 配置 TCP/UDP 传输监听；0 表示不配置传输监听 |
| 自动虚拟地址 | 自动选择虚拟 IPv4 |
| 开机启动 | 系统启动时自动运行 |
| 放行 WAN 端口 | 放行所设非零监听端口 |
| 开启 LAN 转发 | 允许本机 GREEN/BLUE 网段与 VPN 双向转发 |
| LAN 访问源地址转换 | 将 LAN 经隧道发出的流量转换为 VPN 地址；需同时开启 LAN 转发 |
| 对端地址 | 每行一个 URL，支持 tcp、udp、ws、wss、quic |
| 公布的 IPv4 网段 | 向成员公布可达网段，例如 `192.168.50.0/24` |

**保存不会重启进程，但会立即同步防火墙选项。** 网络身份、虚拟地址、对端、监听端口和公布网段等运行配置修改后，需要点击“重启”重新加载。

## WAN 放行

仅作为主动连接端时，通常可保持监听端口为 0、WAN 放行关闭。需要接受连接时，设置非零监听端口并开启“放行 WAN 端口”。

在 **防火墙 → 规则策略** 中可看到两条原生规则：

```text
EasyTier managed WAN TCP
EasyTier managed WAN UDP
```

规则匹配 RED 接口，目标为防火墙 RED 地址和所设端口。保存、启停、端口变更和卸载会同步这些规则。请通过 EasyTier 页面管理，不要手动编辑、改名或复制托管规则，也不要给其他规则使用相同备注。

IPFire 位于上级路由器之后时，仍需按拓扑配置上级端口转发。该选项不会开放管理 RPC。

## LAN 转发

开启 LAN 转发，关闭 NAT，并确保：

- 本地客户端或其默认网关有到远端网段、经 IPFire 转发的路由。
- 远端具有返回本地 GREEN/BLUE 网段的路由。
- 两端防火墙和目标设备服务允许访问。

公布网段不会自动修改客户端或上级网关路由，也不等于已完成防火墙授权。

### 远端访问

如果 IPFire 本机可以访问远端网页，而 LAN 客户端不行，可尝试同时开启 **LAN 转发** 和 **LAN 访问源地址转换（NAT）**。

NAT 仅匹配本机 GREEN/BLUE 源网段，且流量必须实际从 `easytier0` 发出。它适应远端公布网段变化，也包含 VPN 虚拟地址，无需逐台添加 Web 端口规则；不转换普通 WAN 出口流量。

代价是远端看到 IPFire 的 VPN 地址，而不是真实客户端地址。NAT 不会创建路由，不能解决网段冲突、服务未监听或所有远端访问限制。

LAN/NAT 使用 `ETIER_FORWARD`、`ETIER_NAT` 专属链，通过 `/etc/sysconfig/firewall.local` 托管区块恢复重载后的规则，不显示为原生规则页面中的独立条目。取消选项、停止服务或卸载时清理对应规则。

## 注意事项

- **避免网段重叠：** 不要让远端公布与本机 GREEN/BLUE 相同的网段，也不要选择与现有 LAN/VPN 冲突的虚拟地址。
- LAN 转发允许可信 VPN 成员与本机 GREEN/BLUE 双向通信；不自动包含 ORANGE/RED 转发。
- 插件不主动修改 DNS、默认路由或全局转发 sysctl。但 EasyTier 可学习成员公布的路由，应信任私有网络中的全部成员。
- 隧道接口固定为 `easytier0`，管理 RPC 固定为 `127.0.0.1:15889`，应避免与其他程序冲突。
- 管理页面要求管理员 HTTPS 访问，具有 POST/CSRF、配置字段校验及密码不回显机制。
- 配置、日志及卸载备份可能含敏感信息，不要公开上传。

## 故障排除

查看运行状态：

```sh
/usr/local/sbin/easytierctrl status
/usr/local/sbin/easytierctrl peers
/usr/local/sbin/easytierctrl routes
tail -n 80 /var/log/easytier.log
```

能 ping 通但 Web 不通时，分别检查 IPFire 本机和 LAN 客户端，区分服务、防火墙及回程路由；HTTPS 证书警告须另行核对设备身份。

若管理 SSH/Web 异常，从本地控制台停止服务，再检查网段、学习路由和客户端网关：

```sh
/usr/local/sbin/easytierctrl stop
```

恢复管理后，可在插件页面取消开机启动及相关选项。不要通过扩大防火墙放行范围掩盖路由问题。

## 卸载插件

使用仓库安装的插件，以 root 执行：

```sh
ipfrepo remove easytier
```

离线安装的插件，在解压后的插件目录执行：

```sh
bash uninstall.sh
```

卸载会停止服务，先将配置备份到 `/root/easytier-uninstall.XXXXXX/config/`，再清理插件程序、菜单、sudo 规则、启动项、托管防火墙规则和钩子。保留 root 私有日志 `/var/log/easytier.log` 及配置备份；不卸载共享 TUN 模块。

## 上游与许可证

- [EasyTier 项目](https://github.com/EasyTier/EasyTier)
- [捆绑版本 v2.6.4](https://github.com/EasyTier/EasyTier/releases/tag/v2.6.4)

