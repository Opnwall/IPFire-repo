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

print_step "准备卸载 IPFire 汉化补丁"
echo "该操作将删除汉化 Web 页面、专用 root helper、菜单入口、sudo 权限配置，以及保存的下载地址配置。"
read -r -p "是否继续？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

print_step "删除已安装文件"
rm -f /srv/web/ipfire/cgi-bin/lang_install.cgi
rm -f /usr/local/sbin/lang-install-helper
rm -f /var/ipfire/menu.d/78-lang_install.menu
rm -f /etc/sudoers.d/lang-install
rm -f /var/ipfire/lang_install.conf

print_step "校验卸载结果"
[[ ! -e /srv/web/ipfire/cgi-bin/lang_install.cgi ]] || die "lang_install.cgi 删除失败"
[[ ! -e /usr/local/sbin/lang-install-helper ]] || die "lang-install-helper 删除失败"
[[ ! -e /var/ipfire/menu.d/78-lang_install.menu ]] || die "78-lang_install.menu 删除失败"
[[ ! -e /etc/sudoers.d/lang-install ]] || die "lang-install sudoers 文件删除失败"
[[ ! -e /var/ipfire/lang_install.conf ]] || die "lang_install.conf 删除失败"

print_step "重载 Web 服务"
/etc/init.d/apache reload >/dev/null 2>&1 || true

echo
echo "IPFire 汉化补丁卸载完成！"
