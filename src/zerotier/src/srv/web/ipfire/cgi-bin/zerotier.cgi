#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use utf8;

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings = ();
my $service  = "/etc/init.d/zerotier";
my $sudo_cmd = "/usr/bin/sudo";
my $config   = "/var/ipfire/zerotier/settings";

sub zt_tr {
    my ($key) = @_;
    my %en = (
        'zerotier vpn' => 'ZeroTier VPN',
        'zerotier reject non post request' => 'Rejected non-POST request',
        'zerotier reject unknown command' => 'Rejected unknown command',
        'zerotier reject invalid argument' => 'Rejected invalid argument',
        'zerotier unknown' => 'Unknown',
        'zerotier invalid network id' => 'Network ID must be 16 hexadecimal characters',
        'zerotier status refreshed' => 'Status refreshed',
        'zerotier service status' => 'Service Status',
        'zerotier status' => 'Status',
        'zerotier running' => 'Running',
        'zerotier stopped' => 'Stopped',
        'zerotier start' => 'Start',
        'zerotier stop' => 'Stop',
        'zerotier restart' => 'Restart',
        'zerotier refresh' => 'Refresh',
        'zerotier node info' => 'Node Info',
        'zerotier node id' => 'Node ID',
        'zerotier online status' => 'Status',
        'zerotier program version' => 'Version',
        'zerotier network config' => 'Network Configuration',
        'zerotier save' => 'Save',
        'zerotier join' => 'Join',
        'zerotier leave' => 'Leave',
        'zerotier joined networks' => 'Joined Networks',
        'zerotier network id' => 'Network ID',
        'zerotier name' => 'Name',
        'zerotier type' => 'Type',
        'zerotier interface' => 'Interface',
        'zerotier assigned address' => 'Assigned Address',
        'zerotier no network info' => 'No network information',
        'zerotier address' => 'Address',
        'zerotier version' => 'Version',
        'zerotier latency' => 'Latency',
        'zerotier role' => 'Role',
        'zerotier path' => 'Path',
        'zerotier no peer info' => 'No node information',
    );
    my %zh = (
        'zerotier vpn' => 'ZeroTier VPN',
        'zerotier reject non post request' => '拒绝非 POST 请求',
        'zerotier reject unknown command' => '拒绝执行未知命令',
        'zerotier reject invalid argument' => '拒绝执行非法参数',
        'zerotier unknown' => '未知',
        'zerotier invalid network id' => 'Network ID 必须是 16 位十六进制字符',
        'zerotier status refreshed' => '状态已刷新',
        'zerotier service status' => '服务状态',
        'zerotier status' => '状态',
        'zerotier running' => '运行中',
        'zerotier stopped' => '已停止',
        'zerotier start' => '启动',
        'zerotier stop' => '停止',
        'zerotier restart' => '重启',
        'zerotier refresh' => '刷新',
        'zerotier node info' => '节点信息',
        'zerotier node id' => 'ID',
        'zerotier online status' => '状态',
        'zerotier program version' => '版本',
        'zerotier network config' => '网络配置',
        'zerotier save' => '保存',
        'zerotier join' => '加入',
        'zerotier leave' => '离开',
        'zerotier joined networks' => '已加入网络',
        'zerotier network id' => 'Network ID',
        'zerotier name' => '名称',
        'zerotier type' => '类型',
        'zerotier interface' => '网卡',
        'zerotier assigned address' => '分配地址',
        'zerotier no network info' => '暂无网络信息',
        'zerotier address' => '地址',
        'zerotier version' => '版本',
        'zerotier latency' => '延迟',
        'zerotier role' => '角色',
        'zerotier path' => '路径',
        'zerotier no peer info' => '暂无节点信息',
    );
    my %tw = (
        'zerotier vpn' => 'ZeroTier VPN',
        'zerotier reject non post request' => '拒絕非 POST 請求',
        'zerotier reject unknown command' => '拒絕執行未知命令',
        'zerotier reject invalid argument' => '拒絕執行非法參數',
        'zerotier unknown' => '未知',
        'zerotier invalid network id' => 'Network ID 必須是 16 位十六進位字元',
        'zerotier status refreshed' => '狀態已重新整理',
        'zerotier service status' => '服務狀態',
        'zerotier status' => '狀態',
        'zerotier running' => '執行中',
        'zerotier stopped' => '已停止',
        'zerotier start' => '啟動',
        'zerotier stop' => '停止',
        'zerotier restart' => '重新啟動',
        'zerotier refresh' => '重新整理',
        'zerotier node info' => '節點資訊',
        'zerotier node id' => 'ID',
        'zerotier online status' => '狀態',
        'zerotier program version' => '版本',
        'zerotier network config' => '網路設定',
        'zerotier save' => '儲存',
        'zerotier join' => '加入',
        'zerotier leave' => '離開',
        'zerotier joined networks' => '已加入網路',
        'zerotier network id' => 'Network ID',
        'zerotier name' => '名稱',
        'zerotier type' => '類型',
        'zerotier interface' => '網路介面',
        'zerotier assigned address' => '分配位址',
        'zerotier no network info' => '暫無網路資訊',
        'zerotier address' => '位址',
        'zerotier version' => '版本',
        'zerotier latency' => '延遲',
        'zerotier role' => '角色',
        'zerotier path' => '路徑',
        'zerotier no peer info' => '暫無節點資訊',
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
my $network_id  = $settings{'NETWORK_ID'} || '';
my $cmd_output  = '';
my $show_output = 0;
my %post_actions = map { $_ => 1 } qw(start stop restart join leave save_network);

if ($post_actions{$action} && (($ENV{'REQUEST_METHOD'} || '') ne 'POST')) {
    $cmd_output = &zt_tr('zerotier reject non post request');
    $show_output = 1;
    $action = '';
}

sub run_service_command {
    my ($command, @args) = @_;
    my %allowed = map { $_ => 1 } qw(start stop restart status join leave set_network info listnetworks peers);
    return &zt_tr('zerotier reject unknown command') . "\n" unless $allowed{$command};

    for my $arg (@args) {
        return &zt_tr('zerotier reject invalid argument') . "\n" unless defined $arg && $arg =~ /\A[0-9a-fA-F]{16}\z/;
    }

    my $arg_text = join(' ', map { quotemeta($_) } @args);
    return `$sudo_cmd -n $service $command $arg_text 2>&1`;
}

sub read_config_network_id {
    return '' unless -f $config;

    open(my $fh, '<', $config) or return '';
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/\r//g;
        if ($line =~ /^NETWORK_ID=([0-9a-fA-F]{16})$/) {
            close($fh);
            return $1;
        }
    }
    close($fh);
    return '';
}

sub parse_info {
    my $text = run_service_command('info');
    my %info = (
        raw     => $text,
        address => '',
        status  => &zt_tr('zerotier unknown'),
        version => '',
    );

    if ($text =~ /^200\s+info\s+([0-9a-fA-F]+)\s+(\S+)\s+(\S+)/m) {
        $info{'address'} = $1;
        $info{'version'} = $2;
        $info{'status'}  = $3;
    }
    elsif ($text =~ /^200\s+info\s+([0-9a-fA-F]+)\s+(\S+)/m) {
        $info{'address'} = $1;
        $info{'status'}  = $2;
    }

    return %info;
}

sub parse_networks {
    my $text = run_service_command('listnetworks');
    my @rows = ();

    for my $line (split(/\n/, $text)) {
        next if $line =~ /^\s*$/;
        next if $line =~ /^200\s+listnetworks\s+<nwid>/i;

        my @parts = split(/\s+/, $line);
        next unless @parts >= 9;
        next unless $parts[0] eq '200' && $parts[1] eq 'listnetworks';

        my $assigned = join(' ', @parts[8 .. $#parts]);
        $assigned =~ s/^\s+|\s+$//g;

        push @rows, {
            id       => $parts[2],
            name     => $parts[3],
            mac      => $parts[4],
            status   => $parts[5],
            type     => $parts[6],
            dev      => $parts[7],
            assigned => $assigned,
        };
    }

    return @rows;
}

sub parse_peers {
    my $text = run_service_command('peers');
    my @rows = ();

    for my $line (split(/\n/, $text)) {
        next if $line =~ /^\s*$/;
        next if $line =~ /^(?:200\s+)?(?:peers|listpeers)?\s*<ztaddr>/i;

        my @parts = split(/\s+/, $line);
        next unless @parts >= 5;

        if ($parts[0] eq '200' && ($parts[1] eq 'listpeers' || $parts[1] eq 'peers')) {
            if (defined $parts[3] && $parts[3] =~ m{/|;}) {
                push @rows, {
                    address => $parts[2],
                    version => $parts[5] || '',
                    latency => $parts[4] || '',
                    role    => $parts[6] || '',
                    paths   => $parts[3] || '',
                };
            }
            else {
                push @rows, {
                    address => $parts[2],
                    version => $parts[3] || '',
                    latency => $parts[5] || '',
                    role    => $parts[4] || '',
                    paths   => join(' ', @parts[7 .. $#parts]),
                };
            }
            next;
        }

        next unless $parts[0] =~ /^[0-9a-fA-F]{10}$/;
        push @rows, {
            address => $parts[0],
            version => $parts[1] || '',
            latency => $parts[3] || '',
            role    => $parts[2] || '',
            paths   => join(' ', @parts[7 .. $#parts]),
        };
    }

    return @rows;
}

my $saved_network_id = read_config_network_id();

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
elsif ($action eq 'save_network') {
    if ($network_id =~ /\A[0-9a-fA-F]{16}\z/) {
        $cmd_output = run_service_command('set_network', lc($network_id));
        $saved_network_id = lc($network_id);
    }
    else {
        $cmd_output = &zt_tr('zerotier invalid network id');
    }
    $show_output = 1;
}
elsif ($action eq 'join') {
    $cmd_output = run_service_command('join');
    $show_output = 1;
}
elsif ($action eq 'leave') {
    $cmd_output = run_service_command('leave');
    $show_output = 1;
}
elsif ($action eq 'refresh') {
    $cmd_output = &zt_tr('zerotier status refreshed');
    $show_output = 1;
}

my $service_check = run_service_command('status');
my $running = (($? >> 8) == 0 || $service_check =~ /running/i) ? 1 : 0;
my %node = parse_info();
my @networks = parse_networks();
my @peers = parse_peers();

&Header::openpage(&zt_tr('zerotier vpn'), 1, '');
print "<meta charset='UTF-8'>\n";
print <<'EOF';
<style>
.status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
    vertical-align: middle;
}
.status-dot.running { background: #2ecc71; }
.status-dot.stopped { background: #e74c3c; }
.info-table, .zt-table {
    width: 100%;
    border-collapse: collapse;
}
.info-table td, .zt-table th, .zt-table td {
    padding: 6px 8px;
    border-bottom: 1px solid #ddd;
    text-align: left;
    vertical-align: top;
}
.info-table td.key, .zt-table th {
    background: #f7f7f7;
    color: #333;
    font-weight: bold;
}
.zt-ok { color: #2f7d32; font-weight: bold; }
.zt-warn { color: #b26a00; font-weight: bold; }
.ipfire-note {
    margin-top: 8px;
    padding: 6px 8px;
    border: 1px solid #ddd;
    background: #f7f7f7;
    color: #333;
    white-space: pre-wrap;
}
.zt-input {
    width: 220px;
}
.zt-section-title {
    margin-top: 14px;
    padding-top: 10px;
    border-top: 1px solid #ddd;
    font-weight: bold;
}
</style>
EOF

&Header::openbigbox('100%', 'left', '', '');
print "<form method='post'>";

&Header::openbox('100%', 'left', &zt_tr('zerotier service status'));
print "<b>" . &zt_tr('zerotier status') . ":</b> ";
if ($running) {
    print "<span class='status-dot running'></span><span style='color:green;'>" . &zt_tr('zerotier running') . "</span>";
}
else {
    print "<span class='status-dot stopped'></span><span style='color:red;'>" . &zt_tr('zerotier stopped') . "</span>";
}
print "<br><br>";
print "<button type='submit' name='ACTION' value='start'>" . &zt_tr('zerotier start') . "</button>  ";
print "<button type='submit' name='ACTION' value='stop'>" . &zt_tr('zerotier stop') . "</button>  ";
print "<button type='submit' name='ACTION' value='restart'>" . &zt_tr('zerotier restart') . "</button>  ";
print "<button type='submit' name='ACTION' value='refresh'>" . &zt_tr('zerotier refresh') . "</button>";

if ($show_output) {
    print "<br><br><div class='ipfire-note'>";
    print &Header::escape($cmd_output);
    print "</div>";
}
print "<div class='zt-section-title'>" . &zt_tr('zerotier node info') . "</div>";
print "<table class='info-table'>";
print "<tr><td class='key'>" . &zt_tr('zerotier node id') . "</td><td>" . &Header::escape($node{'address'}) . "</td></tr>";
print "<tr><td class='key'>" . &zt_tr('zerotier online status') . "</td><td>" . &Header::escape($node{'status'}) . "</td></tr>";
print "<tr><td class='key'>" . &zt_tr('zerotier program version') . "</td><td>" . &Header::escape($node{'version'}) . "</td></tr>";
print "</table>";
&Header::closebox();

&Header::openbox('100%', 'left', &zt_tr('zerotier network config'));
print &zt_tr('zerotier network id') . ": ";
print "<input class='zt-input' type='text' name='NETWORK_ID' maxlength='16' value='" . &Header::escape($saved_network_id) . "'> ";
print "<button type='submit' name='ACTION' value='save_network'>" . &zt_tr('zerotier save') . "</button>  ";
print "<button type='submit' name='ACTION' value='join'>" . &zt_tr('zerotier join') . "</button>  ";
print "<button type='submit' name='ACTION' value='leave'>" . &zt_tr('zerotier leave') . "</button>";

print "<div class='zt-section-title'>" . &zt_tr('zerotier joined networks') . "</div>";
print "<table class='zt-table'>";
print "<tr><th>" . &zt_tr('zerotier network id') . "</th><th>" . &zt_tr('zerotier name') . "</th><th>" . &zt_tr('zerotier status') . "</th><th>" . &zt_tr('zerotier type') . "</th><th>" . &zt_tr('zerotier interface') . "</th><th>" . &zt_tr('zerotier assigned address') . "</th></tr>";
if (@networks) {
    for my $net (@networks) {
        my $class = ($net->{'status'} eq 'OK') ? 'zt-ok' : 'zt-warn';
        print "<tr>";
        print "<td>" . &Header::escape($net->{'id'}) . "</td>";
        print "<td>" . &Header::escape($net->{'name'}) . "</td>";
        print "<td class='$class'>" . &Header::escape($net->{'status'}) . "</td>";
        print "<td>" . &Header::escape($net->{'type'}) . "</td>";
        print "<td>" . &Header::escape($net->{'dev'}) . "</td>";
        print "<td>" . &Header::escape($net->{'assigned'}) . "</td>";
        print "</tr>";
    }
}
else {
    print "<tr><td colspan='6'>" . &zt_tr('zerotier no network info') . "</td></tr>";
}
print "</table>";
&Header::closebox();

&Header::openbox('100%', 'left', &zt_tr('zerotier node info'));
print "<table class='zt-table'>";
print "<tr><th>" . &zt_tr('zerotier address') . "</th><th>" . &zt_tr('zerotier version') . "</th><th>" . &zt_tr('zerotier latency') . "</th><th>" . &zt_tr('zerotier role') . "</th><th>" . &zt_tr('zerotier path') . "</th></tr>";
if (@peers) {
    for my $peer (@peers) {
        print "<tr>";
        print "<td>" . &Header::escape($peer->{'address'}) . "</td>";
        print "<td>" . &Header::escape($peer->{'version'}) . "</td>";
        print "<td>" . &Header::escape($peer->{'latency'}) . "</td>";
        print "<td>" . &Header::escape($peer->{'role'}) . "</td>";
        print "<td>" . &Header::escape($peer->{'paths'}) . "</td>";
        print "</tr>";
    }
}
else {
    print "<tr><td colspan='5'>" . &zt_tr('zerotier no peer info') . "</td></tr>";
}
print "</table>";
&Header::closebox();

print "</form>";
&Header::closebigbox();
&Header::closepage();
