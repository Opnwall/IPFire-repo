#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use utf8;

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings = ();
my $service  = "/etc/rc.d/init.d/syncthing";
my $sudo_cmd = "/usr/bin/sudo";
my $config   = "/var/ipfire/syncthing/settings";

sub st_tr {
    my ($key) = @_;
    my %en = (
        'syncthing title' => 'Syncthing',
        'syncthing reject non post request' => 'Rejected non-POST request',
        'syncthing reject unknown command' => 'Rejected unknown command',
        'syncthing service status' => 'Service Status',
        'syncthing status' => 'Status',
        'syncthing running' => 'Running',
        'syncthing stopped' => 'Stopped',
        'syncthing start' => 'Start',
        'syncthing stop' => 'Stop',
        'syncthing restart' => 'Restart',
        'syncthing refresh' => 'Refresh',
        'syncthing version' => 'Version',
        'syncthing gui' => 'Links URL',
        'syncthing settings' => 'Settings',
        'syncthing enabled' => 'Enabled',
        'syncthing gui address' => 'Listen address',
        'syncthing save' => 'Save',
        'syncthing saved' => 'Settings saved',
    );
    my %zh = (
        'syncthing title' => 'Syncthing',
        'syncthing reject non post request' => '拒绝非 POST 请求',
        'syncthing reject unknown command' => '拒绝执行未知命令',
        'syncthing service status' => '服务状态',
        'syncthing status' => '状态',
        'syncthing running' => '运行中',
        'syncthing stopped' => '已停止',
        'syncthing start' => '启动',
        'syncthing stop' => '停止',
        'syncthing restart' => '重启',
        'syncthing refresh' => '刷新',
        'syncthing version' => '版本',
        'syncthing gui' => '链接地址',
        'syncthing settings' => '连接设置',
        'syncthing enabled' => '启用',
        'syncthing gui address' => '监听地址',
        'syncthing save' => '保存',
        'syncthing saved' => '设置已保存',
    );
    my %tw = (
        'syncthing title' => 'Syncthing',
        'syncthing reject non post request' => '拒絕非 POST 請求',
        'syncthing reject unknown command' => '拒絕執行未知命令',
        'syncthing service status' => '服務狀態',
        'syncthing status' => '狀態',
        'syncthing running' => '執行中',
        'syncthing stopped' => '已停止',
        'syncthing start' => '啟動',
        'syncthing stop' => '停止',
        'syncthing restart' => '重新啟動',
        'syncthing refresh' => '重新整理',
        'syncthing version' => '版本',
        'syncthing gui' => '連結地址',
        'syncthing settings' => '連線設定',
        'syncthing enabled' => '啟用',
        'syncthing gui address' => '監聽位址',
        'syncthing save' => '儲存',
        'syncthing saved' => '設定已儲存',
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
    $cmd_output = &st_tr('syncthing reject non post request');
    $show_output = 1;
    $action = '';
}

sub run_service_command {
    my ($command) = @_;
    my %allowed = map { $_ => 1 } qw(start stop restart status version);
    return &st_tr('syncthing reject unknown command') . "\n" unless $allowed{$command};
    return `$sudo_cmd -n $service $command 2>&1`;
}

sub read_settings {
    my %cfg = (
        ENABLED => 'on',
        GUI_ADDRESS => '0.0.0.0:8384',
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
    my $tmp = "/tmp/syncthing-settings.$$";

    return "Invalid listen address\n" unless $cfg{'GUI_ADDRESS'} =~ /\A[0-9A-Za-z_.:-]+:[0-9]{2,5}\z/;

    my $fh;
    if (!open($fh, '>', $tmp)) {
        return "Cannot create temporary settings file: $!\n";
    }
    print $fh "ENABLED=$cfg{'ENABLED'}\n";
    print $fh "GUI_ADDRESS=$cfg{'GUI_ADDRESS'}\n";
    close($fh);

    my $out = `$sudo_cmd -n /usr/bin/install -m 600 $tmp $config 2>&1`;
    unlink $tmp;
    return $out || &st_tr('syncthing saved') . "\n";
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
    $cfg{'GUI_ADDRESS'} = $settings{'GUI_ADDRESS'} || '0.0.0.0:8384';
    $cmd_output = write_settings(%cfg);
    $show_output = 1;
}

my $status = run_service_command('status');
my $running = ($status =~ /running/i) ? 1 : 0;
my $version = run_service_command('version');
chomp($version);

my $host = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || $ENV{'SERVER_ADDR'} || '';
$host =~ s/:\d+$//;
my $gui_address = $cfg{'GUI_ADDRESS'} || '0.0.0.0:8384';
my $gui_port = '8384';
$gui_port = $1 if $gui_address =~ /:(\d+)$/;
my $gui_url = "http://" . ($host || '127.0.0.1') . ":" . $gui_port . "/";

&Header::openpage(&st_tr('syncthing title'), 1, '');
&Header::openbigbox('100%', 'left', '', '');

print <<'STYLE';
<style>
.syncthing-status {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
}
.syncthing-status.running { background: #2ecc71; }
.syncthing-status.stopped { background: #e74c3c; }
.syncthing-table {
    width: 100%;
    border-collapse: collapse;
}
.syncthing-table td {
    padding: 6px 8px;
    border-top: 1px solid #d6d6d6;
}
.syncthing-table td:first-child {
    width: 180px;
    font-weight: bold;
}
</style>
STYLE

print "<form method='post'>\n";

&Header::openbox('100%', 'left', &st_tr('syncthing service status'));
print "<table class='syncthing-table'>\n";
print "<tr><td>" . &Header::escape(&st_tr('syncthing status')) . "</td><td>";
if ($running) {
    print "<span class='syncthing-status running'></span>" . &Header::escape(&st_tr('syncthing running'));
} else {
    print "<span class='syncthing-status stopped'></span>" . &Header::escape(&st_tr('syncthing stopped'));
}
print "</td></tr>\n";
print "<tr><td>" . &Header::escape(&st_tr('syncthing version')) . "</td><td><pre style='margin:0;white-space:pre-wrap;'>" . &Header::escape($version) . "</pre></td></tr>\n";
print "<tr><td>" . &Header::escape(&st_tr('syncthing gui')) . "</td><td><a target='_blank' href='" . &Header::escape($gui_url) . "'>" . &Header::escape($gui_url) . "</a></td></tr>\n";
print "</table><br>\n";
print "<button type='submit' name='ACTION' value='start'>" . &Header::escape(&st_tr('syncthing start')) . "</button> ";
print "<button type='submit' name='ACTION' value='stop'>" . &Header::escape(&st_tr('syncthing stop')) . "</button> ";
print "<button type='submit' name='ACTION' value='restart'>" . &Header::escape(&st_tr('syncthing restart')) . "</button> ";
print "<button type='submit' name='ACTION' value='refresh'>" . &Header::escape(&st_tr('syncthing refresh')) . "</button>\n";
if ($show_output) {
    print "<br><br><pre style='background:#111;color:#f66;padding:8px;white-space:pre-wrap;'>" . &Header::escape($cmd_output) . "</pre>\n";
}
&Header::closebox();

&Header::openbox('100%', 'left', &st_tr('syncthing settings'));
my $checked = ($cfg{'ENABLED'} || 'on') eq 'on' ? " checked" : "";
print "<table class='syncthing-table'>\n";
print "<tr><td>" . &Header::escape(&st_tr('syncthing enabled')) . "</td><td><input type='checkbox' name='ENABLED' value='on'$checked></td></tr>\n";
print "<tr><td>" . &Header::escape(&st_tr('syncthing gui address')) . "</td><td><input type='text' name='GUI_ADDRESS' value='" . &Header::escape($cfg{'GUI_ADDRESS'}) . "' style='width:240px;'></td></tr>\n";
print "</table><br>\n";
print "<button type='submit' name='ACTION' value='save'>" . &Header::escape(&st_tr('syncthing save')) . "</button>\n";
&Header::closebox();

print "</form>\n";
&Header::closebigbox();
&Header::closepage();
