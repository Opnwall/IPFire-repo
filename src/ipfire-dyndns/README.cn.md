# IPFire DDNS 服务商补丁

这个补丁包为 IPFire 的 `ddns` 动态域名组件增加以下服务商支持：

- `cloudflare.com`
- `alidns.aliyuncs.com`
- `dnspod.tencentcloudapi.com`

## 文件说明

```text
cloudflare patch/
├── install.sh
├── uninstall.sh
├── README.md
├── README.cn.md
├── ipfire-ddns-cloudflare.patch
└── src/patches/ddns-014-dns-provider-support.patch
```

## 安装

把整个 `cloudflare patch` 文件夹复制到 IPFire 主机上，然后用 `root` 执行：

```sh
chmod +x install.sh uninstall.sh
./install.sh
```

安装脚本会自动完成：

- 备份当前的 `providers.py` 和 `system.py`
- 应用 `src/patches/ddns-014-dns-provider-support.patch`
- 执行 Python 语法检查
- 验证新服务商是否已被 `/usr/bin/ddns` 识别

默认安装路径：

```text
/usr/lib/python3.10/site-packages/ddns
```

如果你的系统路径不同，可以这样指定：

```sh
DDNS_DIR=/path/to/ddns ./install.sh
```

## 卸载

用 `root` 执行：

```sh
./uninstall.sh
```

卸载脚本会优先恢复安装时生成的最新 `*.bak-cloudflare-*` 备份。如果找不到备份，则尝试反向应用补丁。

## IPFire 页面配置方法

进入：

```text
服务 -> 动态 DNS
```

### Cloudflare

服务选择：

```text
cloudflare.com
```

填写方式：

- 主机名：完整域名，例如 `test.example.com`
- 令牌：Cloudflare API Token

Cloudflare Token 至少需要对应 Zone 的 DNS 编辑权限。

### 阿里云云解析 DNS

服务选择：

```text
alidns.aliyuncs.com
```

填写方式：

- 主机名：完整域名，例如 `test.example.com`
- 用户名：阿里云 `AccessKeyId`
- 密码：阿里云 `AccessKeySecret`

对应 RAM 用户需要具备查询、新增、更新云解析 DNS 记录的权限。

### 腾讯云 DNSPod

服务选择：

```text
dnspod.tencentcloudapi.com
```

填写方式：

- 主机名：完整域名，例如 `test.example.com`
- 用户名：腾讯云 `SecretId`
- 密码：腾讯云 `SecretKey`

对应 CAM 用户需要具备查询、创建、修改 DNSPod 记录的权限。

## 注意事项

- Cloudflare 使用 IPFire 页面里的“令牌”字段。
- 阿里云和腾讯云使用 IPFire 页面里的“用户名/密码”字段。
- 目前支持更新 `A` 和 `AAAA` 记录。
- 如果记录已经存在，会尽量保留原有 TTL 和线路设置。
- DNS 记录必须先在服务商后台创建好。补丁默认不会自动创建新记录，避免主机名输错时静默创建不需要的解析记录。
- 补丁默认不会自动删除已有记录。例如当前 IPFire 没有可用 IPv6 地址时，不会自动删除已有的 `AAAA` 记录。
- 如果更新成功后页面主机名仍显示红色，可能是 IPFire 本机 DNS 缓存了旧的 NXDOMAIN 结果。公网 DNS 可能已经正确，刷新本机 DNS 缓存或等待缓存过期即可。

## 验证

安装后检查服务商列表：

```sh
/usr/bin/ddns list-providers | grep -E 'cloudflare.com|alidns.aliyuncs.com|dnspod.tencentcloudapi.com'
/usr/bin/ddns list-token-providers | grep cloudflare.com
```

手动触发更新：

```sh
/usr/local/bin/ddnsctrl update-all
```

查看日志：

```sh
grep -i 'Dynamic DNS update' /var/log/messages | tail
```

建议在正式提交或大范围使用前测试：

- 用 `ddns -d list-providers` 检查服务商是否注册
- 用 `ddns -d guess-ip-addresses` 检查 IPFire 识别到的公网 IP
- 用 `ddns -d update-all --force` 强制更新
- 用 `1.1.1.1` 和 `8.8.8.8` 查询公网 DNS 结果
- 通过服务商 API 确认记录内容
- 记录已是最新时重复执行普通更新
- 错误密钥或 Token
- 主机名对应记录不存在
- 仅 IPv4、仅 IPv6、双栈记录
- 安装和卸载是否干净

## 提交源码补丁

如果要把改动提交到 IPFire 源码树，可以参考：

```text
ipfire-ddns-cloudflare.patch
```

核心补丁文件是：

```text
src/patches/ddns-014-dns-provider-support.patch
```
