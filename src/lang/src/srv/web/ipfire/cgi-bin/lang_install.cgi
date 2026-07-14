#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use utf8;
use Encode qw(decode FB_CROAK FB_DEFAULT);

BEGIN {
    $SIG{__WARN__} = sub {
        warn @_ unless $_[0] =~ /^Wide character in print at /;
    };
}

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings = ();

# ====== 可调整路径与地址 ======
my $lang_url    = 'https://cloud.pfchina.org/index.php/s/CYFKMKGY7spK7mj/download?path=%2FIPFire&files=IPFire_lang.zip';
my $sudo_cmd    = '/usr/bin/sudo';
my $helper_cmd  = '/usr/local/sbin/lang-install-helper';
my $config_file = '/var/ipfire/lang_install.conf';
# =============================

my $cmd_output = '';
my $show_output = 0;
my $status_class = 'info';

my $sudo_prefix = '';
my $sudo_ready  = -1;
my $sudo_error  = '';

sub lang_family {
    my $language = lc($Lang::language || 'en');
    $language =~ s/-/_/g;
    return 'zh_Hans' if $language eq 'zh' || $language =~ /^zh_(cn|hans)/;
    return 'zh_Hant' if $language eq 'tw' || $language =~ /^zh_(tw|hk|hant)/;
    return 'en';
}

sub helper_lang {
    my $family = lang_family();
    return 'zh-Hans' if $family eq 'zh_Hans';
    return 'zh-Hant' if $family eq 'zh_Hant';
    return 'en';
}

sub t {
    my ($key) = @_;
    my $family = lang_family();
    my %messages = (
        page_title => {
            en => 'IPFire Localization Patch',
            zh_Hans => 'IPFire 汉化补丁',
            zh_Hant => 'IPFire 漢化補丁',
        },
        download_url => {
            en => 'Download URL',
            zh_Hans => '下载地址',
            zh_Hant => '下載位址',
        },
        url_hint => {
            en => 'You can customize the download URL. After saving, this URL will be loaded automatically next time.',
            zh_Hans => '可自定义下载地址，保存后，下次打开页面会自动载入该地址。',
            zh_Hant => '可自訂下載位址，儲存後，下次開啟頁面會自動載入該位址。',
        },
        save_url => {
            en => 'Save URL',
            zh_Hans => '保存地址',
            zh_Hant => '儲存位址',
        },
        install_now => {
            en => 'Install Now',
            zh_Hans => '立即汉化',
            zh_Hant => '立即漢化',
        },
        empty_url => {
            en => "Download URL cannot be empty.\n",
            zh_Hans => "下载地址不能为空。\n",
            zh_Hant => "下載位址不能為空。\n",
        },
        saved_url => {
            en => "Default download URL saved.\n",
            zh_Hans => "默认下载地址已保存。\n",
            zh_Hant => "預設下載位址已儲存。\n",
        },
        helper_missing => {
            en => 'Executable helper not found: ',
            zh_Hans => '未找到可执行 helper：',
            zh_Hant => '找不到可執行 helper：',
        },
        sudo_failed => {
            en => "sudo cannot run the helper without a password. Please check /etc/sudoers.d/lang-install.\n",
            zh_Hans => "sudo 无法免密码执行 helper，请检查 /etc/sudoers.d/lang-install。\n",
            zh_Hant => "sudo 無法免密碼執行 helper，請檢查 /etc/sudoers.d/lang-install。\n",
        },
        sudo_missing => {
            en => "sudo is not available and this CGI is not running as root.\n",
            zh_Hans => "未找到可用的 sudo，且当前 CGI 不是以 root 身份运行。\n",
            zh_Hant => "找不到可用的 sudo，且目前 CGI 不是以 root 身分執行。\n",
        },
        privilege_hint => {
            en => "Please make sure the helper is installed and the Web user can run it without a password.\n\n",
            zh_Hans => "请确认 helper 已安装并允许 Web 用户免密码执行。\n\n",
            zh_Hant => "請確認 helper 已安裝，並允許 Web 使用者免密碼執行。\n\n",
        },
        sudoers_hint => {
            en => "sudoers should contain:\n",
            zh_Hans => "sudoers 应包含以下内容：\n",
            zh_Hant => "sudoers 應包含以下內容：\n",
        },
    );
    return $messages{$key}{$family} || $messages{$key}{en} || $key;
}

sub load_saved_lang_url {
    return unless -e $config_file;

    open(my $fh, '<', $config_file) or return;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/;
        next unless $line =~ /^LANG_URL=(.*)$/;
        my $saved = $1;
        $saved =~ s/^['\"]//;
        $saved =~ s/['\"]$//;
        $saved =~ s/^\s+|\s+$//g;
        if ($saved ne '') {
            $lang_url = $saved;
        }
        last;
    }
    close($fh);
}

sub save_lang_url {
    my ($new_url) = @_;
    $new_url = '' unless defined $new_url;
    $new_url =~ s/^\s+|\s+$//g;
    return (0, t('empty_url')) if $new_url eq '';

    my ($code, $out) = run_helper('save-url', $new_url);
    $lang_url = $new_url if $code == 0;
    return ($code == 0, $out ne '' ? $out : t('saved_url'));
}

sub get_priv_prefix {
    return $sudo_prefix if $sudo_ready == 1;

    if (!-x $helper_cmd) {
        $sudo_ready = 0;
        $sudo_error = t('helper_missing') . "$helper_cmd\n";
        return '';
    }

    if ($> == 0) {
        $sudo_prefix = '';
        $sudo_ready  = 1;
        return $sudo_prefix;
    }

    if (-x $sudo_cmd) {
        my $probe = shell_quote($sudo_cmd) . ' -n -l ' . shell_quote($helper_cmd) . ' >/dev/null 2>&1';
        if (system($probe) == 0) {
            $sudo_prefix = shell_quote($sudo_cmd) . ' -n ';
            $sudo_ready  = 1;
            return $sudo_prefix;
        }
        $sudo_error = t('sudo_failed');
        $sudo_ready = 0;
        return '';
    }

    $sudo_ready = 0;
    $sudo_error = t('sudo_missing');
    return '';
}

sub require_privileges {
    get_priv_prefix();
    return (1, '') if $sudo_ready == 1;

    my $msg = '';
    $msg .= $sudo_error if $sudo_error ne '';
    $msg .= t('privilege_hint');
    $msg .= t('sudoers_hint');
    $msg .= "nobody ALL=(root) NOPASSWD: $helper_cmd\n";
    return (0, $msg);
}

sub shell_quote {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/'/'\\''/g;
    return "'$s'";
}

sub decode_post_utf8 {
    my ($value) = @_;
    return '' unless defined $value;
    my $decoded = $value;
    eval {
        $decoded = decode('UTF-8', $value, FB_CROAK);
    };
    return $decoded;
}

sub decode_utf8_output {
    my ($value) = @_;
    return '' unless defined $value;
    return decode('UTF-8', $value, FB_DEFAULT);
}

sub run_cmd {
    my ($cmd) = @_;
    my $out = `$cmd 2>&1`;
    my $code = $? >> 8;
    return ($code, decode_utf8_output($out));
}

sub run_helper {
    my ($action, $arg) = @_;
    my ($priv_ok, $priv_msg) = require_privileges();
    return (1, $priv_msg) unless $priv_ok;

    my $prefix = get_priv_prefix();
    my $cmd = $prefix . shell_quote($helper_cmd) . ' ' . shell_quote($action);
    $cmd .= ' ' . shell_quote($arg) if defined $arg && $arg ne '';
    $cmd .= ' ' . shell_quote(helper_lang());

    my ($code, $out) = run_cmd($cmd);
    return ($code, $out);
}

sub install_lang_patch {
    my ($code, $out) = run_helper('install', $lang_url);
    return ($code == 0, $out);
}

load_saved_lang_url();
print "Content-Type: text/html; charset=UTF-8\n";
print "Cache-Control: private\n\n";
&Header::getcgihash(\%settings);

my $action = $settings{'ACTION'} || '';

if ($action eq 'saveurl') {
    my $new_url = decode_post_utf8($settings{'LANG_URL'} || '');
    my ($ok, $out) = save_lang_url($new_url);
    $cmd_output = $out;
    $show_output = 1;
    $status_class = $ok ? 'ok' : 'error';
}
elsif ($action eq 'install') {
    my $new_url = decode_post_utf8($settings{'LANG_URL'} || '');
    $new_url =~ s/^\s+|\s+$//g;
    if ($new_url ne '') {
        $lang_url = $new_url;
    }

    my ($ok, $out) = install_lang_patch();
    $cmd_output = $out;
    $show_output = 1;
    $status_class = $ok ? 'ok' : 'error';
}
else {
    my $new_url = decode_post_utf8($settings{'LANG_URL'} || '');
    $new_url =~ s/^\s+|\s+$//g;
    if ($new_url ne '') {
        $lang_url = $new_url;
    }
}

&Header::openpage(t('page_title'), 1, '');
print "<meta charset='UTF-8'>\n";

print <<'EOF';
<style>
.lang-toolbar {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
    margin-top: 10px;
}

.lang-toolbar button {
    min-width: 88px;
}

.lang-input {
    width: 100%;
    box-sizing: border-box;
    padding: 6px 8px;
}

.lang-card {
    background: #ececec;
    border: 1px solid #333;
    padding: 14px;
    margin-bottom: 12px;
}

.action-row {
    margin-bottom: 10px;
}

.lang-title {
    font-size: 28px;
    font-weight: bold;
    color: #333;
    margin: 0 0 12px 0;
}

.lang-desc {
    color: #333;
    margin: 0 0 10px 0;
    line-height: 1.5;
}

.lang-hint {
    color: #555;
    font-size: 12px;
    margin-top: 6px;
}

.output-box {
    padding: 12px;
    box-sizing: border-box;
    margin: 0;
    white-space: pre-wrap;
    border: 1px solid #333;
    font-family: monospace;
    line-height: 1.5;
    overflow-x: auto;
}

.output-box.info {
    color: #111;
    background: #f7f7f7;
}

.output-box.ok {
    color: #103810;
    background: #e6f4e6;
}

.output-box.error {
    color: #5a1010;
    background: #f8e3e3;
}
</style>
EOF

&Header::openbigbox('100%', 'left', '', '');
print "<form method='post'>";

print "<div class='lang-card'>";
print "<div class='action-row'>";
print "<b>" . &Header::escape(t('download_url')) . "</b><br>";
print "</div>";
print "<input class='lang-input' type='text' name='LANG_URL' value='" . &Header::escape($lang_url) . "'>";
print "<div class='lang-hint'>" . &Header::escape(t('url_hint')) . "</div>";
print "<div class='lang-toolbar'>";
print "<button type='submit' name='ACTION' value='saveurl'>" . &Header::escape(t('save_url')) . "</button>";
print "<button type='submit' name='ACTION' value='install'>" . &Header::escape(t('install_now')) . "</button>";
print "</div>";
print "</div>";

if ($show_output) {
    print "<pre class='output-box " . &Header::escape($status_class) . "'>";
    print &Header::escape($cmd_output);
    print "</pre>";
}

print "</form>";
&Header::closebigbox();
&Header::closepage();
