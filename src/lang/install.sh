#!/bin/bash
set -euo pipefail

print_step() {
    echo
    echo "==> $1"
}

die() {
    echo "错误：$1" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    die "请使用 root 运行此脚本。"
fi

print_step "准备安装 IPFire 汉化补丁"
echo "该操作将安装汉化 Web 页面、专用 root helper、菜单入口和 sudo 权限配置。"
read -r -p "是否继续？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

print_step "检查源码目录"
[[ -d ./src ]] || die "缺少目录 ./src"
for dir in ./src/srv ./src/usr ./src/var ./src/etc; do
    [[ -d "$dir" ]] || die "缺少目录 $dir"
done

[[ -f ./src/srv/web/ipfire/cgi-bin/lang_install.cgi ]] || die "缺少文件 ./src/srv/web/ipfire/cgi-bin/lang_install.cgi"
[[ -f ./src/usr/local/sbin/lang-install-helper ]] || die "缺少文件 ./src/usr/local/sbin/lang-install-helper"
[[ -f ./src/var/ipfire/menu.d/78-lang_install.menu ]] || die "缺少文件 ./src/var/ipfire/menu.d/78-lang_install.menu"
[[ -f ./src/etc/sudoers.d/lang-install ]] || die "缺少文件 ./src/etc/sudoers.d/lang-install"

print_step "创建必要目录"
install -d -m 755 /srv/web/ipfire/cgi-bin
install -d -m 755 /usr/local/sbin
install -d -m 755 /var/ipfire/menu.d
install -d -m 755 /etc/sudoers.d

print_step "复制文件"
for dir in etc srv usr var; do
    cp -R -f "./src/$dir/." "/$dir/"
done

print_step "设置文件权限"
chown root:root /srv/web/ipfire/cgi-bin/lang_install.cgi /usr/local/sbin/lang-install-helper /var/ipfire/menu.d/78-lang_install.menu /etc/sudoers.d/lang-install 2>/dev/null || true
chmod 755 /srv/web/ipfire/cgi-bin/lang_install.cgi
chmod 755 /usr/local/sbin/lang-install-helper
chmod 644 /var/ipfire/menu.d/78-lang_install.menu
chmod 440 /etc/sudoers.d/lang-install

print_step "校验 sudoers 配置"
visudo -cf /etc/sudoers.d/lang-install >/dev/null || die "sudoers 配置校验失败"

print_step "检查安装结果"
[[ -f /srv/web/ipfire/cgi-bin/lang_install.cgi ]] || die "lang_install.cgi 未安装"
[[ -f /usr/local/sbin/lang-install-helper ]] || die "lang-install-helper 未安装"
[[ -f /var/ipfire/menu.d/78-lang_install.menu ]] || die "78-lang_install.menu 未安装"
[[ -f /etc/sudoers.d/lang-install ]] || die "lang-install sudoers 文件未安装"

print_step "重载 Web 服务"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "IPFire 汉化补丁安装完成！"
echo "现在可以前往 系统>汉化补丁 菜单进行操作。"
