
<div align="center">
  <a href="README.md">中文</a> |
  <a href="README_US.md">English</a>
</div>

# IPFire 版 EasyTier

适用于 IPFire 的社区 EasyTier 组网 VPN 插件。通过 Web 管理界面配置网络名称、密码和对端节点，即可连接不同地点的设备，并可选择访问远程局域网。

这不是 IPFire 或 EasyTier 的官方插件。

## 兼容性

| 项目 | 说明 |
| --- | --- |
| 插件版本 | 1.0.2 |
| 内置二进制 | EasyTier 2.6.4 核心 / CLI |
| 支持的系统 | IPFire 2.29 Core Update 206 |
| 架构 | x86_64 |
| 菜单 | 服务 → EasyTier |
| 界面语言 | 简体中文、繁体中文和英文，跟随 GUI 设置 |

安装程序仅接受此核心版本和架构。本软件包不适用于 ARM 或其他 Core 版本。

## 功能特性

- 使用网络名称和密码加入私有网络。密码不会显示；保存时留空表示保留原值。
- 自动或静态虚拟 IPv4、多个对端节点以及可选的 TCP/UDP 监听端口。
- 发布可通过本设备访问的 IPv4 子网。
- 启动、停止、重启以及可选的开机自启。
- 可横向滚动的对端和路由表格。
- 可选的 WAN 访问，与 IPFire 原生防火墙规则同步。
- 可选的 GREEN/BLUE 双向转发和局域网源 NAT。

未预置任何共享凭据或公共中继。全新安装后服务处于停止状态；开机自启、WAN 访问、局域网转发和 NAT 均未启用。

## 安装

先备份 IPFire；如适用，请创建虚拟机快照，并保留 SSH 或控制台访问方式。在 IPFire 上以 root 身份执行以下命令。

首次使用该仓库时，请先下载并查看仓库安装脚本，然后再运行：

```sh
curl -fsSL https://opnwall.github.io/IPFire-repo/install-repo.sh -o /tmp/install-ipfrepo.sh
sh /tmp/install-ipfrepo.sh
```

安装 EasyTier：

```sh
ipfrepo update
ipfrepo install easytier
```

如果已安装 ipfrepo，可跳过仓库设置步骤。客户端会校验软件包的 SHA-256。可用软件包请参见[社区仓库](https://opnwall.github.io/IPFire-repo/)。

离线安装时，下载并校验压缩包，传输到 IPFire 后执行：

```sh
tar -xzf easytier-1.0.1-x86_64.tar.gz
cd easytier
bash install.sh
```

确认安装成功后，打开 **服务 → EasyTier**。未被管理的冲突文件不会被覆盖。升级会保留插件设置，但会停止服务。

## 快速配置

### 1.0.1 版本变更

- 在三种界面语言中新增节点主机名字段。它只更改 EasyTier 节点名称，不会更改系统主机名。保存并重启 EasyTier 进程后生效。
- 现有设置保持兼容；默认值为 ipfire-easytier，保存旧表单时会保留已配置的名称。
- 保留 STUN 集成，并动态发现 RED 接口/IPv4，而非硬编码测试设备的 WAN 地址。停止服务时会移除专用 STUN 规则和优先级 8999 的 STUN 路由例外。
- 安装程序接受 Core 204/205。已检查 Core 205 下的字段渲染、校验和序列化；本版本未重复进行完整的卸载/重装和整机重启验证。

对于通过仓库安装的现有环境，先运行 `ipfrepo update`，再运行 `ipfrepo install easytier`。升级会停止服务：请先检查设置，之后再启动。插件的「重启」按钮重启的是 EasyTier，而不是 IPFire。

1. 输入与其他成员相同的网络名称和密码。
2. 输入一个可达的对端节点，每行一个，例如 `tcp://vpn.example.net:11010`。
3. 保持自动虚拟地址开启，或关闭它并分配一个未使用的静态地址，例如 `10.126.0.10/24`。
4. 点击「保存」，然后点击「启动」。
5. 在「对端」和「路由」中检查连通性和已发布的子网。
6. 在启用开机自启或其他权限之前，先验证连通性和管理访问。

自动分配的地址可能在重启后发生变化。需要稳定端点时，请使用已确认未使用的静态地址。

## 配置项

| 设置 | 说明 |
| --- | --- |
| 网络名称 | 私有网络标识符，各成员共享 |
| 节点主机名 | VPN 节点名称；支持字母、数字、连字符和点分名称。留空则恢复为 ipfire-easytier。保存并重启 EasyTier 后生效；系统主机名不变 |
| 网络密码 | 私有网络密码；留空表示保留已保存的值 |
| 虚拟 IPv4 | 静态地址/前缀，例如 10.126.0.10/24；自动模式下为空 |
| 监听端口 | 配置 TCP/UDP 监听；0 表示不配置传输监听 |
| 自动虚拟 IP | 自动选择虚拟 IPv4 |
| 开机启动 | 随 IPFire 一起启动 |
| 允许 WAN 监听端口 | 允许已配置的非零监听端口 |
| 启用局域网转发 | 允许本地 GREEN/BLUE 与 VPN 之间的双向流量 |
| 局域网源 NAT | 将经隧道发往 VPN 的局域网流量转换为 VPN 地址；需启用转发 |
| 对端节点 | 每行一个 URL；支持 tcp、udp、ws、wss 和 quic |
| 发布的 IPv4 子网 | 发布可达子网，例如 192.168.50.0/24 |

**保存不会重启进程，但会立即应用防火墙选项。** 更改网络身份、虚拟地址、对端节点、监听端口或发布子网后，请重启服务。

## WAN 访问

仅出站连接的节点通常可以保持监听和 WAN 访问关闭。要接受入站连接，请设置非零监听端口并启用 WAN 访问。

**防火墙 → 防火墙规则**下会出现两条原生规则：

```text
EasyTier managed WAN TCP
EasyTier managed WAN UDP
```

它们匹配 RED 接口、防火墙 RED 地址和所配置的端口。保存、启动/停止、更改端口或卸载时都会同步这些规则。请通过 EasyTier 管理它们；不要手动编辑、重命名或复制这些规则，也不要在其他无关规则中复用其备注。

如果 IPFire 位于另一台路由器之后，请按需配置上游端口转发。此选项不会暴露管理 RPC。

## 局域网转发

若要保留客户端地址，请启用局域网转发但不启用 NAT，并确保：

- 客户端或其默认网关将远程子网的流量路由到 IPFire。
- 远端存在指向本地 GREEN/BLUE 子网的回程路由。
- 防火墙和目标服务允许访问。

发布子网不会配置客户端/上游路由，也不会授予防火墙权限。

### 远程访问

如果 IPFire 可以访问远程网站，而局域网客户端不能，请尝试同时启用**局域网转发**和**局域网源 NAT**。

NAT 只匹配本地 GREEN/BLUE 源子网以及实际从 `easytier0` 发出的流量。它能适应远程子网发布的变化，并包含 VPN 虚拟地址；普通 WAN 流量不会被转换。

远端设备看到的将是 IPFire 的 VPN 地址，而不是原始客户端地址。NAT 不会创建路由，也无法解决子网冲突、服务不可用或所有远程访问限制。

局域网/NAT 使用专用的 ETIER_FORWARD 和 ETIER_NAT 链，通过 /etc/sysconfig/firewall.local 中的受管区块恢复。它们不会显示为独立的原生防火墙条目。禁用相关选项、停止服务或卸载时会清理相应规则。

## 重要提示

- 避免网络重叠：远程发布的子网不得与本地 GREEN/BLUE 子网重复，虚拟地址不得与现有局域网或 VPN 冲突。
- 局域网转发会授予受信任的 VPN 成员对本地 GREEN/BLUE 的双向访问权限；它不会自动包含 ORANGE/RED 转发。
- 插件不会显式改写 DNS、默认路由或全局转发 sysctl。EasyTier 可以学习成员发布的路由，因此请信任私有网络中的每一个成员。
- 接口固定为 easytier0，管理 RPC 固定为 127.0.0.1:15889；请避免与其他软件冲突。
- Web 管理界面需要已认证的管理员 HTTPS 访问，并提供 POST/CSRF 校验、字段校验和密码脱敏。
- 配置、日志和卸载备份可能包含敏感信息。请勿公开它们。

## 故障排查

```sh
/usr/local/sbin/easytierctrl status
/usr/local/sbin/easytierctrl peers
/usr/local/sbin/easytierctrl routes
tail -n 80 /var/log/easytier.log
```

如果可以 ping 通但无法访问 Web，请对比从 IPFire 和从局域网客户端发起的测试，以区分服务、防火墙和回程路由问题。接受 HTTPS 证书警告前，请先确认目标身份。

如果 SSH/Web 管理变得不可访问，请从本地控制台停止服务，然后检查重叠子网、已学习的路由和客户端网关：

```sh
/usr/local/sbin/easytierctrl stop
```

管理恢复后，按需禁用开机自启或相关选项。请勿通过大范围开放防火墙权限来掩盖路由问题。

## 卸载

通过仓库安装的：

```sh
ipfrepo remove easytier
```

离线安装的，请在解压后的插件目录中运行：

```sh
bash uninstall.sh
```

卸载会停止服务，将设置备份到 /root/easytier-uninstall.XXXXXX/config/，并移除插件程序、菜单、sudo 规则、启动项、受管防火墙规则和钩子。仅 root 可读的 /var/log/easytier.log 和配置备份会保留。共享的 TUN 模块不会被卸载。

## 上游与许可证

上游 LGPL-3.0 许可证见 [LICENSE.EasyTier](LICENSE.EasyTier)。

- [EasyTier 项目](https://github.com/EasyTier/EasyTier)
- [内置的 v2.6.4 版本](https://github.com/EasyTier/EasyTier/releases/tag/v2.6.4)
