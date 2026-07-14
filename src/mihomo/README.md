## Mihomo for IPFire
![IPFire](https://img.shields.io/badge/IPFire-2.29-orange)
![Mihomo](https://img.shields.io/badge/Mihomo-MetaCubeX-purple)

Mihomo（原 Clash Meta）是一款高性能、功能丰富的开源代理核心，兼容 Clash 配置格式，并在此基础上扩展了更多协议和高级功能，支持多种代理协议，提供灵活的规则分流、DNS 管理、负载均衡和透明代理功能。凭借其优秀的性能和广泛的兼容性，Mihomo 已成为构建现代网络代理和流量管理解决方案的重要工具之一。

本项目是一个用于 IPFire 的 Mihomo 插件，用于在 IPFire 上运行 Mihomo 并实现透明代理功能。

在IPFire-2.29-x86_64-Core-Update-203上测试通过。

![](image/mihomo.png)

## 集成程序
[mihomo](https://github.com/metacubex/mihomo)

## 注意事项
1. 当前仅支持x86_64 平台。
2. 脚本集成了可用的默认设置，只需替换proxies和rule部分配置即可使用。
3. 为减少长期运行保存的日志数量，在调试完成后，将日志层级修改为error。

## 安装命令
以 root 用户登录终端，运行以下命令安装：
```bash
bash install.sh
```
## 卸载命令
以 root 用户登录终端，运行以下命令卸载：
```bash
bash uninstall.sh
```

## 配置过程
1. 安装完成，导航到 服务>Mihomo 菜单，修改配置并保存。
2. 点击启动按钮，根据输出日志内容，排除配置文件错误。

## 其他事项
1. 脚本具备开机自启功能。
2. 默认配置文件开启了 api 功能，访问 http://lan_ip:9090/ui 登录 Mihomo 仪表盘(metacubexd)。

## 免责声明
这是一个非官方社区项目，与 IPFire 团队没有任何关联，自行承担使用过程中可能产生的风险。