<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Speedtest for IPFire

<p>
  <img src="https://img.shields.io/badge/IPFire-2.29%20Core%20206-orange" alt="IPFire">
  <img src="https://img.shields.io/badge/Platform-x86__64-blue" alt="Platform">
</p>

> 插件版本：**1.0.5** · 适用系统：**IPFire 2.29 Core Update 206（x86_64）**

插件版本：**1.0.5**，适用系统：**IPFire 2.29 Core Update 206，x86_64**

Speedtest 在 IPFire 管理页面的“服务”菜单中添加测速入口，用于测试防火墙自身到互联网测速服务器的连接速度。

## 功能

- 自动选择出站接口，或选择具有 IPv4 默认路由和全局 IPv4 地址的接口。
- 手动刷新测速服务器列表，自动选择服务器或指定服务器。
- 设置 1～16 个并发连接。
- 显示下载速度、上传速度、延迟、抖动和丢包率；具体字段取决于测速服务器和引擎返回的数据。
- 显示测试时间、运营商、公网 IP、服务器及距离等信息。
- 在后台执行测速，页面自动查询进度。
- 保存最近一次测速结果和成功测速后的设置，支持清除结果。
- 首次测速失败后，自动选择服务器重试一次。

测速通过随包提供的 speedtest-go 引擎执行，安装时无需另行下载引擎。测速需要设备能够访问互联网和测速服务器。

## 安装插件

### 从社区仓库安装

已配置 IPFire 社区仓库及 `ipfrepo` 的设备，以 root 身份执行：

```sh
ipfrepo update
ipfrepo install speedtest
```

### 手动安装

下载并解压插件安装包，进入包含 `install.sh` 的 `speedtest` 目录，以 root 身份执行：

```sh
chmod +x install.sh uninstall.sh
./install.sh
```

按提示输入 `y` 确认。安装程序会复制测速引擎、Web 页面、菜单、语言资源和权限配置，并尝试重载 Web 服务。

安装完成后，进入 **服务 > Speedtest**，也可访问管理地址下的 `/cgi-bin/speedtest.cgi`。

## 使用

1. 选择出站接口，通常可保留“自动选择”。
2. 点击“刷新服务器”。更换出站接口后，应重新刷新服务器列表。
3. 保留服务器“自动选择”，或从列表中指定服务器。
4. 设置并发连接数，点击“开始测速”。
5. 等待页面显示结果；需要删除已保存结果时，点击“清除结果”。

下载和上传速度以 **Mbps** 显示，延迟和抖动以 **ms** 显示。测速会占用当前互联网带宽，结果也会受服务器负载、链路、设备性能和并发连接数影响。

本插件测量 IPFire 到互联网服务器的速度；局域网终端的 Wi-Fi 或网线传输性能需要另外测试。

## 文件位置

| 用途 | 路径 |
| --- | --- |
| 管理页面 | `/srv/web/ipfire/cgi-bin/speedtest.cgi` |
| 测速引擎 | `/usr/local/bin/ipfire-speedtest` |
| 管理辅助命令 | `/usr/local/sbin/ipfire-speedtestctl` |
| 设置、服务器缓存和最近一次结果 | `/var/ipfire/speedtest/` |
| 最近一次结果文件 | `/var/ipfire/speedtest/result.json` |

## 常见问题

**出站接口列表为空或缺少接口**：检查设备是否具有 IPv4 默认路由，以及对应接口是否分配了全局 IPv4 地址。当前接口筛选使用 IPv4 路由。

**无法获取服务器列表**：检查 IPFire 自身的 DNS 解析、互联网连接和出站访问策略，再刷新服务器列表。获取列表有 45 秒超时限制。

**测速失败或等待较久**：尝试自动选择服务器、刷新列表或降低并发连接数。每次引擎测速最多等待 120 秒；失败后会自动重试一次，因此总等待时间可能超过两分钟。

**界面语言未变化**：确认 IPFire 的界面语言设置后重新打开页面。插件识别英文，以及 Core 206 使用的简体、繁体语言标识。

## 卸载插件

在解压后的插件目录中，以 root 身份执行：

```sh
./uninstall.sh
```

按提示确认后，将删除插件页面、引擎、菜单、权限和语言资源，**同时删除 `/var/ipfire/speedtest/` 中保存的设置、服务器缓存及测速结果**。需要保留的数据请先备份。

## 第三方许可

随包引擎 speedtest-go 使用 MIT 许可证，许可证副本位于 `third_party/speedtest-go.LICENSE`。

## 免责声明

这是社区维护的非官方项目，与 IPFire 团队没有隶属关系。使用者需自行评估并承担使用风险。
