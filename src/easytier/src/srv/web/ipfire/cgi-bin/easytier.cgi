#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI ();
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);
use Encode qw(encode decode FB_CROAK);
require '/var/ipfire/general-functions.pl';
require '/var/ipfire/lang.pl';
require '/var/ipfire/header.pl';

sub fail { print "Status: 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nForbidden\n"; exit; }
fail() unless ($ENV{REMOTE_USER}//'') eq 'admin' && ($ENV{HTTPS}//'') eq 'on';
$CGI::POST_MAX=16384;
$CGI::DISABLE_UPLOADS=1;
my $cgi=CGI->new;
fail() if $cgi->cgi_error;
my %params;
for my $key ($cgi->param) {
    my @v=$cgi->multi_param($key);
    fail() unless @v==1;
    $params{$key}=eval { decode('UTF-8',$v[0],FB_CROAK) };
    fail() if $@;
}
open my $keyfile,'<:raw','/var/ipfire/easytier/csrf.key' or die 'Cannot read CSRF key';
my $key=do {local $/; <$keyfile>}; close $keyfile;
sub token {
    my ($stamp)=@_;
    return $stamp.'.'.hmac_sha256_hex(join('|','easytier',$ENV{REMOTE_USER},$ENV{REMOTE_ADDR}//'',$stamp),$key);
}
my $csrf=token(time());
sub control {
    my ($action)=@_;
    open my $pipe,'-|','/usr/bin/sudo','-n','/usr/local/sbin/easytierctrl',$action or die 'Control unavailable';
    my $output=do { local $/; <$pipe> };
    my $ok=close $pipe;
    return ($ok,$output//'');
}
my $action=$params{ACTION}//'';
my ($notice,$details)=('','');
if (($ENV{REQUEST_METHOD}//'') eq 'POST') {
    my $given=$params{CSRF_TOKEN}//'';
    fail() unless $given =~ /^(\d{10})\.([a-f0-9]{64})\z/;
    my $stamp=$1;
    fail() if $stamp>time()+30 || time()-$stamp>3600 || $given ne token($stamp);
    fail() unless $action =~ /^(?:save|start|stop|restart|peers|routes)\z/;
    my $ok;
    if ($action eq 'save') {
        my %data=map {$_=>($params{$_}//'')} qw(network_name network_secret ipv4 peers proxy_networks);
        for (qw(peers proxy_networks)) {$data{$_}=join(' ',split /\s+/,$data{$_});}
        $data{dhcp}=($params{dhcp}//'') eq 'on' ? JSON::PP::true : JSON::PP::false;
        $data{boot}=($params{boot}//'') eq 'on' ? JSON::PP::true : JSON::PP::false;
        for (qw(wan_access lan_forward lan_nat)) {
            $data{$_}=($params{$_}//'') eq 'on' ? JSON::PP::true : JSON::PP::false;
        }
        my $port=$params{listener_port}//'0';
        fail() unless $port =~ /^\d{1,5}\z/;
        $data{listener_port}=0+$port;
        open my $pipe,'|-','/usr/bin/sudo','-n','/usr/local/sbin/easytierctrl','save' or die 'Control unavailable';
        print $pipe JSON::PP->new->utf8->encode(\%data);
        $ok=close $pipe;
    } else {($ok,$details)=control($action);}
    $notice=$ok ? 'OK' : 'Failed: check configuration or ask root to inspect /var/log/easytier.log.';
} elsif (length $action) {fail();}
my ($ok,$raw)=control('status');
my $status=eval {JSON::PP->new->utf8->decode($raw)};
die 'Status unavailable' unless $ok && ref($status) eq 'HASH';
my $s=$status->{config};
my %main; General::readhash('/var/ipfire/main/settings',\%main);
my $language=$main{LANGUAGE}//'en';
my %traditional=(
    'Status: '=>'執行狀態：', 'Running'=>'執行中', 'Stopped'=>'已停止',
    'Network name'=>'網路名稱', 'Network password (blank keeps existing)'=>'網路密碼（留空保留）',
    'Virtual IPv4 (empty with DHCP)'=>'虛擬 IPv4（自動位址時留空）',
    'Listener port (0 disables listeners)'=>'監聽連接埠（0 為不監聽）',
    'Automatic virtual IP'=>'自動虛擬位址', 'Start at boot'=>'開機啟動',
    'Allow WAN listener port'=>'放行 WAN 連接埠',
    'Enable LAN forwarding (GREEN/BLUE)'=>'啟用 LAN 轉送（GREEN/BLUE）',
    'LAN source NAT (requires forwarding)'=>'LAN 存取來源位址轉換（須啟用轉送）',
    'NAT applies only to local GREEN/BLUE traffic routed out easytier0, including remote subnets and virtual addresses. Remote devices see the VPN address instead of the client address. No RED/WAN NAT is added.'=>'NAT 僅轉換本機 GREEN/BLUE 經 easytier0 路由的流量（含遠端網段及虛擬位址）。遠端看到的是 VPN 位址而非用戶端位址，不新增 RED/WAN NAT。',
    'Peers (one per line)'=>'對端位址（每行一個）',
    'Advertised IPv4 subnets (optional)'=>'公布的 IPv4 網段（選填）',
    'Save'=>'儲存', 'Start'=>'啟動', 'Stop'=>'停止', 'Restart'=>'重新啟動',
    'Peers'=>'節點', 'Routes'=>'路由', 'OK'=>'成功',
    'Failed: check configuration or ask root to inspect /var/log/easytier.log.'=>'失敗：請檢查設定，或請 root 查看 /var/log/easytier.log。',
    'Saving does not restart the process, but applies firewall options immediately. WAN access requires a nonzero listener port. LAN forwarding permits bidirectional access between trusted mesh members and local GREEN/BLUE subnets, without NAT. RPC remains loopback-only.'=>
    '儲存不會重新啟動程序，但會立即更新防火牆選項。放行 WAN 須設定非零監聽連接埠；LAN 轉送允許私有網路成員與本機 GREEN/BLUE 網段雙向互訪，不新增 NAT。RPC 始終僅監聽本機。',
);
sub label {return $language eq 'tw' ? ($traditional{$_[1]}//$_[1]) : $language eq 'zh' ? $_[0] : $_[1];}
sub esc {my $v=$_[0]//''; $v =~ s/&/&amp;/g; $v =~ s/</&lt;/g; $v =~ s/>/&gt;/g; $v =~ s/"/&quot;/g; $v =~ s/'/&#39;/g; return $v;}
sub out {print encode('UTF-8',$_[0]);}
Header::showhttpheaders();
Header::openpage('EasyTier',1,'');
Header::openbigbox('100%','left');
Header::openbox('100%','left','EasyTier');
out('<p>'.esc(label($notice eq 'OK' ? '成功' : '失败：请检查配置，或请 root 查看 /var/log/easytier.log。',$notice)).'</p>') if $notice;
out('<p>'.label('运行状态：','Status: ').($status->{running} ? label('运行中','Running') : label('已停止','Stopped')).'</p>');
out('<p>'.label('保存不重启进程，但立即更新防火墙选项。放行 WAN 需设置非零监听端口；LAN 转发允许私有网络成员与本机 GREEN/BLUE 网段双向互访，不添加 NAT。RPC 始终仅监听本机。','Saving does not restart the process, but applies firewall options immediately. WAN access requires a nonzero listener port. LAN forwarding permits bidirectional access between trusted mesh members and local GREEN/BLUE subnets, without NAT. RPC remains loopback-only.').'</p>');
out("<form method='post'><input type='hidden' name='CSRF_TOKEN' value='$csrf'><table>");
for my $field (
    ['network_name',label('网络名称','Network name'),'text'],
    ['network_secret',label('网络密码（留空保留）','Network password (blank keeps existing)'),'password'],
    ['ipv4',label('虚拟 IPv4（自动地址时留空）','Virtual IPv4 (empty with DHCP)'),'text'],
    ['listener_port',label('监听端口（0 为不监听）','Listener port (0 disables listeners)'),'number']) {
    my ($name,$label,$type)=@$field;
    my $value=$name eq 'network_secret' ? '' : esc($s->{$name});
    out("<tr><td>$label</td><td><input name='$name' type='$type' value='$value' maxlength='128' autocomplete='off'></td></tr>");
}
my %checks=(dhcp=>label('自动虚拟地址','Automatic virtual IP'), boot=>label('开机启动','Start at boot'),
            wan_access=>label('放行 WAN 端口','Allow WAN listener port'), lan_forward=>label('开启 LAN 转发（GREEN/BLUE）','Enable LAN forwarding (GREEN/BLUE)'),
            lan_nat=>label('LAN 访问源地址转换（需开启转发）','LAN source NAT (requires forwarding)'));
for my $name (qw(dhcp boot wan_access lan_forward lan_nat)) {
    my $label=$checks{$name};
    out("<tr><td>$label</td><td><input type='checkbox' name='$name' value='on'".($s->{$name}?' checked':'')."></td></tr>");
}
for my $name (qw(peers proxy_networks)) {
    my $label=$name eq 'peers' ? label('对端地址（每行一个）','Peers (one per line)') : label('公布的 IPv4 网段（可选）','Advertised IPv4 subnets (optional)');
    my $value=esc(join("\n",split /\s+/,$s->{$name}//''));
    out("<tr><td>$label</td><td><textarea name='$name' rows='3' cols='60'>$value</textarea></td></tr>");
}
out('</table>');
out('<p>'.label('NAT 仅转换本机 GREEN/BLUE 经 easytier0 路由的流量（含远端网段及虚拟地址）。远端看到的是 VPN 地址而非客户端地址，不新增 RED/WAN NAT。','NAT applies only to local GREEN/BLUE traffic routed out easytier0, including remote subnets and virtual addresses. Remote devices see the VPN address instead of the client address. No RED/WAN NAT is added.').'</p>');
for my $button (['save',label('保存','Save')],['start',label('启动','Start')],['stop',label('停止','Stop')],['restart',label('重启','Restart')],['peers',label('节点','Peers')],['routes',label('路由','Routes')]) {
    out("<button name='ACTION' value='$button->[0]'>$button->[1]</button> ");
}
out('</form>');
if (length $details) {
    my @lines=grep { /^\s*\|/ && !/^\s*\|[-:|\s]+\|\s*$/ } split /\n/,decode('UTF-8',$details);
    out('<div style="max-width:100%;overflow-x:auto;margin-top:16px"><table style="border-collapse:collapse;width:100%;white-space:nowrap">');
    my $header=1;
    for my $line (@lines) {
        $line =~ s/^\s*\|//; $line =~ s/\|\s*$//;
        out('<tr>');
        for my $cell (split /\|/,$line,-1) {
            $cell =~ s/^\s+|\s+$//g;
            my $tag=$header?'th':'td';
            out("<$tag style='padding:7px 10px;border:1px solid #ddd;text-align:left'>".esc($cell)."</$tag>");
        }
        out('</tr>'); $header=0;
    }
    out('</table></div>');
}
Header::closebox(); Header::closebigbox(); Header::closepage();
