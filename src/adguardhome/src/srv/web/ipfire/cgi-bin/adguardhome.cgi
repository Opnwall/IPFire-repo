#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use utf8;

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings = ();
my $service  = "/etc/rc.d/init.d/adguardhome";
my $sudo_cmd = "/usr/bin/sudo";
my $config   = "/var/ipfire/adguardhome/settings";

sub agh_tr {
    my ($key) = @_;
    my %en = (
        'adguardhome title' => 'AdGuard Home',
        'adguardhome reject non post request' => 'Rejected non-POST request',
        'adguardhome reject unknown command' => 'Rejected unknown command',
        'adguardhome service status' => 'Service Status',
        'adguardhome status' => 'Status',
        'adguardhome running' => 'Running',
        'adguardhome stopped' => 'Stopped',
        'adguardhome start' => 'Start',
        'adguardhome stop' => 'Stop',
        'adguardhome restart' => 'Restart',
        'adguardhome refresh' => 'Refresh',
        'adguardhome version' => 'Version',
        'adguardhome gui' => 'Links URL',
        'adguardhome settings' => 'Settings',
        'adguardhome enabled' => 'Enabled',
        'adguardhome web address' => 'Web listen address',
        'adguardhome save' => 'Save',
        'adguardhome saved' => 'Settings saved',
        'adguardhome first run' => 'Complete the first-run wizard in the AdGuard Home web interface.',
    );
    my %zh = (
        'adguardhome title' => 'AdGuard Home',
        'adguardhome reject non post request' => '拒绝非 POST 请求',
        'adguardhome reject unknown command' => '拒绝执行未知命令',
        'adguardhome service status' => '服务状态',
        'adguardhome status' => '状态',
        'adguardhome running' => '运行中',
        'adguardhome stopped' => '已停止',
        'adguardhome start' => '启动',
        'adguardhome stop' => '停止',
        'adguardhome restart' => '重启',
        'adguardhome refresh' => '刷新',
        'adguardhome version' => '版本',
        'adguardhome gui' => '链接地址',
        'adguardhome settings' => '连接设置',
        'adguardhome enabled' => '启用',
        'adguardhome web address' => 'Web 监听地址',
        'adguardhome save' => '保存',
        'adguardhome saved' => '设置已保存',
        'adguardhome first run' => '请在 AdGuard Home Web 界面完成首次运行向导。',
    );
    my %tw = (
        'adguardhome title' => 'AdGuard Home',
        'adguardhome reject non post request' => '拒絕非 POST 請求',
        'adguardhome reject unknown command' => '拒絕執行未知命令',
        'adguardhome service status' => '服務狀態',
        'adguardhome status' => '狀態',
        'adguardhome running' => '執行中',
        'adguardhome stopped' => '已停止',
        'adguardhome start' => '啟動',
        'adguardhome stop' => '停止',
        'adguardhome restart' => '重新啟動',
        'adguardhome refresh' => '重新整理',
        'adguardhome version' => '版本',
        'adguardhome gui' => '連結地址',
        'adguardhome settings' => '連線設定',
        'adguardhome enabled' => '啟用',
        'adguardhome web address' => 'Web 監聽位址',
        'adguardhome save' => '儲存',
        'adguardhome saved' => '設定已儲存',
        'adguardhome first run' => '請在 AdGuard Home Web 介面完成首次執行精靈。',
    );

    if (($Lang::language || '') eq 'tw' && exists $tw{$key}) {
        return $tw{$key};
    }
    if (($Lang::language || '') eq 'zh' && exists $zh{$key}) {
        return $zh{$key};
    }
    if (exists $en{$key}) {
        return $en{$key};
    }
    return $Lang::tr{$key} if defined $Lang::tr{$key} && $Lang::tr{$key} ne '';
    return $key;
}

&Header::showhttpheaders();
&Header::getcgihash(\%settings);

my $action      = $settings{'ACTION'} || '';
my $cmd_output  = '';
my $show_output = 0;
my %post_actions = map { $_ => 1 } qw(start stop restart save);

sub request_is_safe_for_action {
    return 1 if $action eq '';
    return 0 if (($ENV{'REQUEST_METHOD'} || '') ne 'POST');

    my $host = $ENV{'HTTP_HOST'} || '';
    return 0 if $host eq '';

    my $seen_source_header = 0;
    foreach my $header ('HTTP_ORIGIN', 'HTTP_REFERER') {
        my $value = $ENV{$header} || '';
        next if $value eq '';
        $seen_source_header = 1;
        return 0 if $value !~ m{^https?://\Q$host\E(?:/|$)}i;
    }

    return $seen_source_header;
}

if ($post_actions{$action} && !request_is_safe_for_action()) {
    $cmd_output = &agh_tr('adguardhome reject non post request');
    $show_output = 1;
    $action = '';
}

sub run_service_command {
    my ($command) = @_;
    my %allowed = map { $_ => 1 } qw(start stop restart status version);
    return &agh_tr('adguardhome reject unknown command') . "\n" unless $allowed{$command};
    return `$sudo_cmd -n $service $command 2>&1`;
}

sub read_settings {
    my %cfg = (
        ENABLED => 'on',
        WEB_ADDRESS => '0.0.0.0:3000',
    );

    if (open(my $fh, '<', $config)) {
        while (my $line = <$fh>) {
            chomp $line;
            $line =~ s/\r//g;
            next if $line =~ /^\s*(?:#|$)/;
            if ($line =~ /^\s*([A-Z_]+)=(.*)$/) {
                $cfg{$1} = $2;
            }
        }
        close($fh);
    }

    return %cfg;
}

sub write_settings {
    my (%cfg) = @_;
    my $tmp = "/tmp/adguardhome-settings.$$";

    return "Invalid web listen address\n" unless $cfg{'WEB_ADDRESS'} =~ /\A[0-9A-Za-z_.:-]+:[0-9]{2,5}\z/;

    my $fh;
    if (!open($fh, '>', $tmp)) {
        return "Cannot create temporary settings file: $!\n";
    }
    print $fh "ENABLED=$cfg{'ENABLED'}\n";
    print $fh "WEB_ADDRESS=$cfg{'WEB_ADDRESS'}\n";
    close($fh);

    my $out = `$sudo_cmd -n /usr/bin/install -m 600 $tmp $config 2>&1`;
    unlink $tmp;
    return $out || &agh_tr('adguardhome saved') . "\n";
}

my %cfg = read_settings();

if ($action eq 'start') {
    $cmd_output = run_service_command('start');
    $show_output = 1;
}
elsif ($action eq 'stop') {
    $cmd_output = run_service_command('stop');
    $show_output = 1;
}
elsif ($action eq 'restart') {
    $cmd_output = run_service_command('restart');
    $show_output = 1;
}
elsif ($action eq 'save') {
    $cfg{'ENABLED'} = ($settings{'ENABLED'} || '') eq 'on' ? 'on' : 'off';
    $cfg{'WEB_ADDRESS'} = $settings{'WEB_ADDRESS'} || '0.0.0.0:3000';
    $cmd_output = write_settings(%cfg);
    $show_output = 1;
}

my $status = run_service_command('status');
my $running = ($status =~ /running/i) ? 1 : 0;
my $version = run_service_command('version');
chomp($version);

my $host = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || $ENV{'SERVER_ADDR'} || '';
$host =~ s/:\d+$//;
my $web_address = $cfg{'WEB_ADDRESS'} || '0.0.0.0:3000';
my $web_port = '3000';
$web_port = $1 if $web_address =~ /:(\d+)$/;
my $gui_url = "http://" . ($host || '127.0.0.1') . ":" . $web_port . "/";

&Header::openpage(&agh_tr('adguardhome title'), 1, '');
&Header::openbigbox('100%', 'left', '', '');

print <<'STYLE';
<style>
.adguardhome-status {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
}
.adguardhome-status.running { background: #2ecc71; }
.adguardhome-status.stopped { background: #e74c3c; }
.adguardhome-table {
    width: 100%;
    border-collapse: collapse;
}
.adguardhome-table td {
    padding: 6px 8px;
    border-top: 1px solid #d6d6d6;
}
.adguardhome-table td:first-child {
    width: 180px;
    font-weight: bold;
}
</style>
STYLE

print "<form method='post'>\n";

&Header::openbox('100%', 'left', &agh_tr('adguardhome service status'));
print "<table class='adguardhome-table'>\n";
print "<tr><td>" . &Header::escape(&agh_tr('adguardhome status')) . "</td><td>";
if ($running) {
    print "<span class='adguardhome-status running'></span>" . &Header::escape(&agh_tr('adguardhome running'));
} else {
    print "<span class='adguardhome-status stopped'></span>" . &Header::escape(&agh_tr('adguardhome stopped'));
}
print "</td></tr>\n";
print "<tr><td>" . &Header::escape(&agh_tr('adguardhome version')) . "</td><td><pre style='margin:0;white-space:pre-wrap;'>" . &Header::escape($version) . "</pre></td></tr>\n";
print "<tr><td>" . &Header::escape(&agh_tr('adguardhome gui')) . "</td><td><a target='_blank' href='" . &Header::escape($gui_url) . "'>" . &Header::escape($gui_url) . "</a><br>" . &Header::escape(&agh_tr('adguardhome first run')) . "</td></tr>\n";
print "</table><br>\n";
print "<button type='submit' name='ACTION' value='start'>" . &Header::escape(&agh_tr('adguardhome start')) . "</button> ";
print "<button type='submit' name='ACTION' value='stop'>" . &Header::escape(&agh_tr('adguardhome stop')) . "</button> ";
print "<button type='submit' name='ACTION' value='restart'>" . &Header::escape(&agh_tr('adguardhome restart')) . "</button> ";
print "<button type='submit' name='ACTION' value='refresh'>" . &Header::escape(&agh_tr('adguardhome refresh')) . "</button>\n";
if ($show_output) {
    print "<br><br><pre style='background:#111;color:#f66;padding:8px;white-space:pre-wrap;'>" . &Header::escape($cmd_output) . "</pre>\n";
}
&Header::closebox();

&Header::openbox('100%', 'left', &agh_tr('adguardhome settings'));
my $checked = ($cfg{'ENABLED'} || 'on') eq 'on' ? " checked" : "";
print "<table class='adguardhome-table'>\n";
print "<tr><td>" . &Header::escape(&agh_tr('adguardhome enabled')) . "</td><td><input type='checkbox' name='ENABLED' value='on'$checked></td></tr>\n";
print "<tr><td>" . &Header::escape(&agh_tr('adguardhome web address')) . "</td><td><input type='text' name='WEB_ADDRESS' value='" . &Header::escape($cfg{'WEB_ADDRESS'}) . "' style='width:240px;'></td></tr>\n";
print "</table><br>\n";
print "<button type='submit' name='ACTION' value='save'>" . &Header::escape(&agh_tr('adguardhome save')) . "</button>\n";
&Header::closebox();

print "</form>\n";
&Header::closebigbox();
&Header::closepage();
