#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use utf8;
use JSON::PP qw(decode_json encode_json);

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %form;
my $sudo = '/usr/bin/sudo';
my $ctl = '/usr/local/sbin/ipfire-speedtestctl';
my $state_dir = '/var/ipfire/speedtest';

sub tr_text {
    my ($key) = @_;
    my %en = (
        title=>'Speedtest', settings=>'Test Settings', result=>'Test Result', interface=>'Outbound Interface', automatic=>'Automatic', interface_help=>'Only interfaces with an IPv4 default route are shown.', server=>'Test Server', server_auto=>'Automatic selection', server_help=>'Refresh the server list after changing the outbound interface.', refresh=>'Refresh Servers', threads=>'Connections', run=>'Start Test', clear=>'Clear Result', running=>'Testing, please wait.......', refreshing=>'Retrieving test servers.', time=>'Test Time', isp=>'ISP / Public IP', test_server=>'Test Server', distance=>'Distance', engine=>'Engine', latency=>'Latency', jitter=>'Jitter', loss=>'Packet Loss', download=>'Download', upload=>'Upload', failed=>'The speed test failed.'
    );
    my %zh = (
        title=>'Speedtest', settings=>'测速设置', result=>'测速结果', interface=>'出站接口', automatic=>'自动选择', interface_help=>'仅显示具有 IPv4 默认路由的接口。', server=>'测速服务器', server_auto=>'自动选择', server_help=>'更改出站接口后，请刷新服务器列表。', refresh=>'刷新服务器', threads=>'并发连接', run=>'开始测速', clear=>'清除结果', running=>'正在测速，请等待.......', refreshing=>'正在获取测速服务器。', time=>'测试时间', isp=>'运营商 / 公网 IP', test_server=>'测速服务器', distance=>'距离', engine=>'测速引擎', latency=>'延迟', jitter=>'抖动', loss=>'丢包率', download=>'下载', upload=>'上传', failed=>'互联网测速失败。'
    );
    my %tw = (
        title=>'Speedtest', settings=>'測速設定', result=>'測速結果', interface=>'出站介面', automatic=>'自動選擇', interface_help=>'僅顯示具有 IPv4 預設路由的介面。', server=>'測速伺服器', server_auto=>'自動選擇', server_help=>'變更出站介面後，請重新整理伺服器清單。', refresh=>'重新整理伺服器', threads=>'並行連線', run=>'開始測速', clear=>'清除結果', running=>'正在測速，請等待.......', refreshing=>'正在取得測速伺服器。', time=>'測試時間', isp=>'電信業者 / 公網 IP', test_server=>'測速伺服器', distance=>'距離', engine=>'測速引擎', latency=>'延遲', jitter=>'抖動', loss=>'封包遺失率', download=>'下載', upload=>'上傳', failed=>'網際網路測速失敗。'
    );
    return $tw{$key} if ($Lang::language || '') eq 'tw' && exists $tw{$key};
    return $zh{$key} if ($Lang::language || '') eq 'zh' && exists $zh{$key};
    return $en{$key} // $key;
}

sub request_is_safe {
    return 0 unless ($ENV{'REQUEST_METHOD'} || '') eq 'POST';
    my $host = $ENV{'HTTP_HOST'} || '';
    return 0 if $host eq '';
    my $seen = 0;
    for my $header ('HTTP_ORIGIN', 'HTTP_REFERER') {
        my $value = $ENV{$header} || '';
        next if $value eq '';
        $seen = 1;
        return 0 unless $value =~ m{^https?://\Q$host\E(?:/|$)}i;
    }
    return $seen;
}

sub run_ctl {
    my (@args) = @_;
    return "Invalid command\n" unless @args && $args[0] =~ /^(?:interfaces|refresh|start|run|clear)$/;
    for my $arg (@args) { return "Invalid parameter\n" unless $arg =~ /^[A-Za-z0-9_.:-]+$/; }
    my $command = join(' ', $sudo, '-n', $ctl, @args) . ' 2>&1';
    return `$command`;
}

sub read_settings {
    my %cfg = (interface=>'auto', server_id=>'auto', threads=>'4');
    if (open(my $fh, '<', "$state_dir/settings")) {
        while (<$fh>) { chomp; $cfg{$1}=$2 if /^(interface|server_id|threads)=(.*)$/; }
        close($fh);
    }
    return %cfg;
}

sub interfaces {
    my @items = ({name=>'auto', address=>'', label=>tr_text('automatic')});
    for my $line (split /\n/, run_ctl('interfaces')) {
        my ($name,$address,$label) = split /\t/, $line, 3;
        next unless defined $label && $name =~ /^[A-Za-z0-9_.:-]+$/ && $address =~ /^\d+(?:\.\d+){3}$/;
        push @items, {name=>$name,address=>$address,label=>$label};
    }
    return @items;
}

sub server_key { my ($interface)=@_; $interface =~ s/[^A-Za-z0-9_]//g; return $interface || 'auto'; }

sub servers {
    my ($interface) = @_;
    my @items;
    my $file = "$state_dir/servers-" . server_key($interface) . '.txt';
    if (open(my $fh, '<', $file)) {
        while (my $line=<$fh>) {
            chomp $line;
            if ($line =~ /^\[\s*(\d+)\]\s+([0-9.]+)km\s+([0-9.]+ms)\s+(.+?)\s+\((.*?)\)\s+by\s+(.+)$/) {
                push @items, {id=>$1,distance=>$2,latency=>$3,name=>$4,country=>$5,sponsor=>$6};
            }
        }
        close($fh);
    }
    return @items;
}

sub read_result {
    return undef unless open(my $fh, '<', "$state_dir/result.json");
    local $/; my $raw=<$fh>; close($fh);
    my $result; eval { $result=decode_json($raw); };
    return ref($result) eq 'HASH' ? $result : undef;
}

sub read_job {
    my ($status, $log) = ('', '');
    if (open(my $fh, '<', "$state_dir/job-status")) {
        chomp($status=<$fh> // '');
        close($fh);
        $status='' unless $status =~ /^(?:running|success|error)$/;
    }
    if ($status eq 'error' && open(my $fh, '<', "$state_dir/job.log")) {
        local $/; $log=<$fh> // ''; close($fh);
        $log=substr($log, -2000) if length($log)>2000;
    }
    return ($status, $log);
}

&Header::showhttpheaders();
&Header::getcgihash(\%form);
my %cfg = read_settings();
my $message = '';
my $error = '';
my $action = $form{'ACTION'} || '';

if ($action ne '') {
    if (!request_is_safe()) { $error='Rejected unsafe request'; }
    elsif ($action eq 'refresh') {
        my $interface=$form{'INTERFACE'}||'auto';
        $error='Invalid outbound interface' unless $interface =~ /^(?:auto|[A-Za-z0-9_.:-]+)$/;
        if ($error eq '') { $message=run_ctl('refresh',$interface); $error=$message if $message =~ /^(?:Error|sudo:)/; $cfg{'interface'}=$interface; $cfg{'server_id'}='auto'; }
    }
    elsif ($action eq 'run') {
        my $interface=$form{'INTERFACE'}||'auto'; my $server=$form{'SERVER'}||'auto'; my $threads=$form{'THREADS'}||'4';
        if ($interface !~ /^(?:auto|[A-Za-z0-9_.:-]+)$/ || $server !~ /^(?:auto|\d+)$/ || $threads !~ /^\d+$/ || $threads<1 || $threads>16) { $error='Invalid test settings'; }
        else {
            $message=run_ctl('start',$interface,$server,$threads);
            $error=$message if $message !~ /started/;
            $cfg{'interface'}=$interface; $cfg{'server_id'}=$server; $cfg{'threads'}=$threads;
        }
    }
    elsif ($action eq 'clear') { $message=run_ctl('clear'); }
    else { $error='Invalid action'; }
}

my @interfaces=interfaces();
my %valid_if=map { $_->{'name'}=>1 } @interfaces;
$cfg{'interface'}='auto' unless $valid_if{$cfg{'interface'}};
my @servers=servers($cfg{'interface'});
my $result=read_result();
my ($job_status,$job_log)=read_job();
$error=$job_log || tr_text('failed') if $error eq '' && $job_status eq 'error';
my $server_result=$result && ref($result->{'servers'}) eq 'ARRAY' ? $result->{'servers'}[0] : undef;
my $user=$result && ref($result->{'user_info'}) eq 'HASH' ? $result->{'user_info'} : {};

&Header::openpage(tr_text('title'), 1, '');
&Header::openbigbox('100%', 'left', '', '');
print <<'STYLE';
<style>
.speedtest-summary{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));border:1px solid #ccc;margin-bottom:14px}.speedtest-metric{padding:16px;border-right:1px solid #ccc;background:#fff}.speedtest-metric:last-child{border-right:0}.speedtest-metric span{color:#667;display:block;font-size:12px}.speedtest-metric strong{display:block;font-size:24px;margin-top:5px;white-space:nowrap}.speedtest-result,.speedtest-form{width:100%;border-collapse:collapse}.speedtest-result td,.speedtest-form td{border-top:1px solid #ddd;padding:7px 15px}.speedtest-result td:first-child,.speedtest-form td:first-child{font-weight:bold;width:190px}.speedtest-control{box-sizing:border-box;max-width:480px;width:100%;height:32px}.speedtest-help{color:#667;font-size:12px;margin-top:4px}.speedtest-actions button,.speedtest-refresh{margin-right:5px;margin-top:7px}.speedtest-status{background:#d9edf7;border:1px solid #bce8f1;padding:10px;margin-bottom:12px;display:none}.speedtest-error{background:#f2dede;border:1px solid #ebccd1;color:#a94442;padding:10px;margin-bottom:12px}@media(max-width:800px){.speedtest-summary{grid-template-columns:1fr 1fr}.speedtest-metric{border-bottom:1px solid #ccc}}
</style>
STYLE
print "<div class='speedtest-error'>".&Header::escape($error)."</div>" if $error ne '';
my $status_style=$job_status eq 'running' ? " style='display:block'" : '';
print "<div id='speedtest-status' class='speedtest-status'${status_style}>".&Header::escape(tr_text('running'))."</div>";
print "<div id='speedtest-job' data-status='".&Header::escape($job_status)."' data-log='".&Header::escape($job_log)."' style='display:none'></div>";

if ($server_result) {
    my $lat=($server_result->{'latency'}||0)/1_000_000; my $jit=($server_result->{'jitter'}||0)/1_000_000;
    my $dl=($server_result->{'dl_speed'}||0)*8/1_000_000; my $ul=($server_result->{'ul_speed'}||0)*8/1_000_000;
    my $packet=$server_result->{'packet_loss'}||{}; my $loss='N/A';
    if (($packet->{'sent'}||0)>0) { $loss=sprintf('%.2f%%',100*(1-(($packet->{'sent'}-$packet->{'dup'})/($packet->{'max'}+1)))); }
    print "<div class='speedtest-summary'>";
    for my $metric ([latency=>sprintf('%.2f ms',$lat)],[jitter=>sprintf('%.2f ms',$jit)],[loss=>$loss],[download=>sprintf('%.2f Mbps',$dl)],[upload=>sprintf('%.2f Mbps',$ul)]) { print "<div class='speedtest-metric'><span>".&Header::escape(tr_text($metric->[0]))."</span><strong>".&Header::escape($metric->[1])."</strong></div>"; }
    print "</div>";
    &Header::openbox('100%','left',tr_text('result'));
    print "<table class='speedtest-result'>";
    my $isp=join(' / ',grep {defined $_ && $_ ne ''} ($user->{'Isp'}||$user->{'isp'},$user->{'IP'}||$user->{'ip'}));
    my @rows=([time=>$result->{'timestamp'}],[isp=>$isp],[test_server=>'['.($server_result->{'id'}||'').'] '.($server_result->{'name'}||'').' - '.($server_result->{'sponsor'}||'')],[distance=>sprintf('%.2f km',$server_result->{'distance'}||0)],[engine=>'speedtest-go 1.7.10']);
    for my $row (@rows) { print '<tr><td>'.&Header::escape(tr_text($row->[0])).'</td><td>'.&Header::escape($row->[1]||'').'</td></tr>'; }
    print '</table>'; &Header::closebox();
}

print "<form method='post' id='speedtest-form'>";
&Header::openbox('100%','left',tr_text('settings'));
print "<table class='speedtest-form'>";
print '<tr><td>'.&Header::escape(tr_text('interface')).'</td><td><select class="speedtest-control" name="INTERFACE">';
for my $item (@interfaces) { my $selected=$cfg{'interface'} eq $item->{'name'}?' selected':''; my $label=$item->{'label'}.($item->{'name'} eq 'auto'?'':' ('.$item->{'name'}.')'); print '<option value="'.&Header::escape($item->{'name'}).'"'.$selected.'>'.&Header::escape($label).'</option>'; }
print '</select><div class="speedtest-help">'.&Header::escape(tr_text('interface_help')).'</div></td></tr>';
print '<tr><td>'.&Header::escape(tr_text('server')).'</td><td><select class="speedtest-control" name="SERVER"><option value="auto">'.&Header::escape(tr_text('server_auto')).'</option>';
for my $item (@servers) { my $selected=$cfg{'server_id'} eq $item->{'id'}?' selected':''; my $label='['.$item->{'id'}.'] '.$item->{'name'}.' - '.$item->{'sponsor'}.' / '.$item->{'latency'}.' / '.sprintf('%.1f',$item->{'distance'}).' km'; print '<option value="'.$item->{'id'}.'"'.$selected.'>'.&Header::escape($label).'</option>'; }
print '</select><div class="speedtest-help">'.&Header::escape(tr_text('server_help')).'</div></td></tr>';
print '<tr><td>'.&Header::escape(tr_text('threads')).'</td><td><input class="speedtest-control" type="number" min="1" max="16" name="THREADS" value="'.&Header::escape($cfg{'threads'}).'" /></td></tr>';
print '<tr><td></td><td class="speedtest-actions"><button type="button" value="run" data-status="run">'.&Header::escape(tr_text('run')).'</button><button type="button" value="clear" data-status="clear">'.&Header::escape(tr_text('clear')).'</button><button class="speedtest-refresh" type="button" value="refresh" data-status="refresh">'.&Header::escape(tr_text('refresh')).'</button></td></tr>';
print '</table>'; &Header::closebox(); print '</form>';
my $running=tr_text('running'); my $refreshing=tr_text('refreshing');
my $failed=tr_text('failed');
print "<script>(function(){var f=document.getElementById('speedtest-form'),s=document.getElementById('speedtest-status'),j=document.getElementById('speedtest-job'),busy=false,running=".encode_json($running).",refreshing=".encode_json($refreshing).",failed=".encode_json($failed).";function show(m,bad){s.textContent=m;s.className=bad?'speedtest-error':'speedtest-status';s.style.display='block';}function parse(t){var d=new DOMParser().parseFromString(t,'text/html'),e=d.querySelector('div.speedtest-error'),m=d.getElementById('speedtest-job');return{error:e?e.textContent.trim():'',status:m?m.dataset.status:'',log:m?m.dataset.log:''};}function get(u,o){return fetch(u,o).then(function(r){if(!r.ok){throw new Error('HTTP '+r.status);}return r.text();});}function poll(){get(window.location.href,{credentials:'same-origin',cache:'no-store'}).then(function(t){var p=parse(t);if(p.status==='success'){window.location.assign(window.location.pathname);return;}if(p.status==='error'||p.error){throw new Error(p.log||p.error||failed);}if(p.status!=='running'){throw new Error(failed);}setTimeout(poll,2000);}).catch(function(e){busy=false;show(e.message||failed,true);});}function start(b){if(busy){return;}busy=true;var d=new FormData(f),mode=b.dataset.status;d.set('ACTION',b.value);if(mode!=='clear'){show(mode==='refresh'?refreshing:running,false);}b.disabled=true;get(window.location.href,{method:'POST',body:d,credentials:'same-origin',cache:'no-store'}).then(function(t){var p=parse(t);if(p.error){throw new Error(p.error);}if(mode==='refresh'||mode==='clear'){window.location.assign(window.location.pathname);return;}if(p.status==='success'){window.location.assign(window.location.pathname);return;}if(p.status!=='running'){throw new Error(p.log||failed);}poll();}).catch(function(e){busy=false;show(e.message||failed,true);b.disabled=false;});}Array.prototype.forEach.call(f.querySelectorAll('button[data-status]'),function(b){b.addEventListener('click',function(e){e.preventDefault();start(b);});});f.addEventListener('submit',function(e){e.preventDefault();});if(j&&j.dataset.status==='running'){busy=true;show(running,false);poll();}})();</script>";
&Header::closebigbox();
&Header::closepage();
