#!/usr/bin/perl
use strict;
use utf8;
no warnings 'utf8';
use Encode qw(decode encode FB_CROAK);
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json);

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings=();

# ====== 可调整路径 ======
my $service      = "/etc/init.d/mihomo";
my $mihomo_conf  = "/usr/local/etc/mihomo/config.yaml";
my $mihomo_log   = "/var/log/mihomo.log";
my $sudo_cmd     = "/usr/bin/sudo";
# ========================

my %fallback = (
    page_title => 'Mihomo',
    service_status => 'Service Status',
    status => 'Status',
    running => 'Running',
    stopped => 'Stopped',
    start => 'Start',
    stop => 'Stop',
    restart => 'Restart',
    config_file => 'Configuration File',
    save_config => 'Save Configuration',
    live_log => 'Live Log',
    clear_log => 'Clear Log',
    loading => 'Loading...',
    log_file_unreadable => 'Unable to read log file',
    command_failed => 'Unable to execute command',
    invalid_service_command => 'Invalid service command',
    temp_config_failed => 'Unable to create temporary configuration file',
    config_check_failed => 'Configuration validation failed',
    backup_failed => 'Configuration backup failed',
    save_write_failed => 'Save failed: unable to write configuration file',
    save_check_failed => 'Save failed: configuration validation did not pass',
    config_saved => 'Configuration saved',
    save_no_config => 'Save failed: no configuration content received',
    request_rejected => 'Request rejected: management actions must come from the current Web UI',
    log_cleared => 'Log cleared',
    log_load_failed => 'Log loading failed, HTTP status: ',
);

my %fallback_zh = (
    page_title => 'Mihomo',
    service_status => '服务状态',
    status => '状态',
    running => '运行中',
    stopped => '已停止',
    start => '启动',
    stop => '停止',
    restart => '重启',
    config_file => '配置文件',
    save_config => '保存配置',
    live_log => '实时日志',
    clear_log => '清空日志',
    loading => '加载中...',
    log_file_unreadable => '无法读取日志文件',
    command_failed => '无法执行命令',
    invalid_service_command => '非法服务命令',
    temp_config_failed => '无法创建临时配置文件',
    config_check_failed => '配置校验失败',
    backup_failed => '配置备份失败',
    save_write_failed => '保存失败：无法写入配置文件',
    save_check_failed => '保存失败：配置校验未通过',
    config_saved => '配置已保存',
    save_no_config => '保存失败：未收到配置内容',
    request_rejected => '请求被拒绝：管理操作必须来自当前 Web 界面',
    log_cleared => '日志已清空',
    log_load_failed => '日志加载失败，HTTP 状态: ',
);

my %fallback_tw = (
    page_title => 'Mihomo',
    service_status => '服務狀態',
    status => '狀態',
    running => '執行中',
    stopped => '已停止',
    start => '啟動',
    stop => '停止',
    restart => '重新啟動',
    config_file => '設定檔',
    save_config => '儲存設定',
    live_log => '即時記錄',
    clear_log => '清除記錄',
    loading => '載入中...',
    log_file_unreadable => '無法讀取記錄檔',
    command_failed => '無法執行命令',
    invalid_service_command => '非法服務命令',
    temp_config_failed => '無法建立暫存設定檔',
    config_check_failed => '設定驗證失敗',
    backup_failed => '設定備份失敗',
    save_write_failed => '儲存失敗：無法寫入設定檔',
    save_check_failed => '儲存失敗：設定驗證未通過',
    config_saved => '設定已儲存',
    save_no_config => '儲存失敗：未收到設定內容',
    request_rejected => '請求被拒絕：管理操作必須來自目前 Web 介面',
    log_cleared => '記錄已清除',
    log_load_failed => '記錄載入失敗，HTTP 狀態: ',
);

sub L {
    my ($key) = @_;
    if (($Lang::language || '') eq 'tw' && exists $fallback_tw{$key}) {
        return $fallback_tw{$key};
    }
    if (($Lang::language || '') eq 'zh' && exists $fallback_zh{$key}) {
        return $fallback_zh{$key};
    }
    return $fallback{$key} || $key;
}

sub strip_ansi {
    my ($text) = @_;
    $text ||= '';
    $text =~ s/\e\[[0-9;?]*[ -\/]*[@-~]//g;
    return $text;
}

&Header::getcgihash(\%settings);

# ====== AJAX 日志接口 ======
my $is_ajax_log = (
    (defined $settings{'ajax'} && $settings{'ajax'} eq 'log') ||
    (($ENV{'QUERY_STRING'} || '') =~ /(?:^|&)ajax=log(?:&|$)/)
);

if ($is_ajax_log) {
    print "Content-Type: text/plain; charset=UTF-8\n";
    print "Cache-Control: no-cache, no-store, must-revalidate\n";
    print "Pragma: no-cache\n";
    print "Expires: 0\n\n";

    my $log_output = '';
    if (open(my $logfh, '<:encoding(UTF-8)', $mihomo_log)) {
        my @lines = <$logfh>;
        close($logfh);
        @lines = @lines > 50 ? @lines[-50 .. -1] : @lines;
        $log_output = strip_ansi(join('', @lines));
    } else {
        $log_output = L('log_file_unreadable') . ": $mihomo_log ($!)\n";
    }
    print encode('UTF-8', $log_output);
    exit;
}

&Header::showhttpheaders();

my $action = $settings{'ACTION'} || '';
my $cmd_output = '';
my $show_output = 0;
my $save_message = '';

sub decode_post_utf8 {
    my ($value) = @_;
    return '' unless defined $value;
    my $decoded = $value;
    eval {
        $decoded = decode('UTF-8', $value, FB_CROAK);
    };
    return $decoded;
}

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

sub normalize_command_output {
    my ($out) = @_;
    $out ||= '';
    return $out;
}

sub run_command {
    my (@cmd) = @_;
    my $out = '';
    if (open(my $fh, "-|", @cmd)) {
        local $/;
        $out = <$fh>;
        close($fh);
    } else {
        $out = L('command_failed') . ": $!";
    }
    return normalize_command_output($out);
}

sub run_service_command {
    my ($command) = @_;
    return L('invalid_service_command') . "\n" unless $command =~ /^(?:start|stop|restart|status)$/;
    return run_command($sudo_cmd, "-n", $service, $command);
}

sub clear_log_file {
    return run_command($sudo_cmd, "-n", "/usr/bin/truncate", "-s", "0", $mihomo_log);
}

sub copy_mihomo_data_files {
    my ($tmp_dir) = @_;
    foreach my $name ('geoip.metadb', 'geosite.dat') {
        my $source = "/usr/local/etc/mihomo/$name";
        next if !-e $source;
        copy($source, "$tmp_dir/$name");
    }
}

sub validate_config_text {
    my ($conf_text) = @_;

    my $tmp_dir = tempdir("mihomo_check_XXXXXX", TMPDIR => 1, CLEANUP => 1);
    my $tmp_conf = "$tmp_dir/config.yaml";

    my $fh;
    if (!open($fh, ">:encoding(UTF-8)", $tmp_conf)) {
        return (0, L('temp_config_failed'));
    }
    print $fh $conf_text;
    close($fh);

    copy_mihomo_data_files($tmp_dir);

    my $out = run_command("/usr/local/bin/mihomo", "-t", "-d", $tmp_dir);
    my $code = $? >> 8;
    if ($code == 0) {
        return (1, normalize_command_output($out));
    }

    return (0, normalize_command_output($out || L('config_check_failed')));
}

sub write_config_file {
    my ($conf_text) = @_;
    my $backup_warning = '';

    if (-e $mihomo_conf) {
        if (!copy($mihomo_conf, "${mihomo_conf}.bak")) {
            $backup_warning = L('backup_failed') . ": $!";
        }
    }

    my $fh;
    if (!open($fh, ">:encoding(UTF-8)", $mihomo_conf)) {
        return (0, L('save_write_failed'));
    }
    print $fh $conf_text;
    if (!close($fh)) {
        return (0, L('save_write_failed'));
    }

    return (1, $backup_warning);
}

# ====== 保存配置 / 服务控制 ======
if (!request_is_safe_for_action()) {
    $cmd_output = L('request_rejected');
    $show_output = 1;
}
elsif ($action eq 'saveconf') {
    if (defined $settings{'CONF'}) {
        my $conf_text = decode_post_utf8($settings{'CONF'});

        my ($ok, $check_out) = validate_config_text($conf_text);
        if (!$ok) {
            $cmd_output = L('save_check_failed') . "\n" . $check_out;
            $show_output = 1;
        } else {
            my ($saved, $save_out) = write_config_file($conf_text);
            if ($saved) {
                $save_message = L('config_saved');
                $cmd_output = $save_out ? "$save_message\n$save_out" : $save_message;
            } else {
                $cmd_output = $save_out;
            }
            $show_output = 1;
        }
    } else {
        $cmd_output = L('save_no_config');
        $show_output = 1;
    }
}
elsif ($action eq 'start') {
    my $clear_out = clear_log_file();
    my $out = run_service_command('start');
    $cmd_output = ($clear_out ? $clear_out : '') . $out;
    $show_output = 1;
}
elsif ($action eq 'stop') {
    my $out = run_service_command('stop');
    $cmd_output = $out;
    $show_output = 1;
}
elsif ($action eq 'restart') {
    my $clear_out = clear_log_file();
    my $out = run_service_command('restart');
    $cmd_output = ($clear_out ? $clear_out : '') . $out;
    $show_output = 1;
}
elsif ($action eq 'clearlog') {
    my $out = clear_log_file();
    $cmd_output = ($out ? $out : '') . L('log_cleared');
    $show_output = 1;
}

# ====== 状态检测 ======
my $status = run_service_command('status');
chomp $status;

# ====== 页面 ======
&Header::openpage(L('page_title'), 1, '');
print "<meta charset='UTF-8'>\n";

print <<'EOF';
<style>
.status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
}
.status-dot.running { background: #2ecc71; }
.status-dot.stopped { background: #e74c3c; }
</style>
EOF

&Header::openbigbox('100%', 'left', '', '');
print "<form method='post'>";

# ====== 状态 ======
&Header::openbox('100%', 'left', L('service_status'));

print "<b>" . L('status') . ":</b> ";
if ($status =~ /running/i) {
    print "<span class='status-dot running'></span><span style='color:green;'>" . L('running') . "</span>";
} else {
    print "<span class='status-dot stopped'></span><span style='color:red;'>" . L('stopped') . "</span>";
}

print "<br><br>";

print "<button type='submit' name='ACTION' value='start'>" . L('start') . "</button>  ";
print "<button type='submit' name='ACTION' value='stop'>" . L('stop') . "</button>  ";
print "<button type='submit' name='ACTION' value='restart'>" . L('restart') . "</button>  ";

if ($show_output) {
    print "<br><br><pre style='color:#ff3333;background:#111;padding:5px;white-space:pre-wrap;'>";
    print &Header::escape($cmd_output);
    print "</pre>";
}

&Header::closebox();

# ====== 配置 ======
&Header::openbox('100%', 'left', L('config_file'));

print "<div><button type='submit' name='ACTION' value='saveconf'>" . L('save_config') . "</button></div>";

my $conf_content = '';
if (-e $mihomo_conf) {
    open(my $fh, "<:encoding(UTF-8)", $mihomo_conf);
    local $/;
    $conf_content = <$fh>;
    close($fh);
}

print "<textarea name='CONF' style='width:100%;height:200px;'>";
print &Header::escape($conf_content);
print "</textarea>";

&Header::closebox();

# ====== 日志 ======
&Header::openbox('100%', 'left', L('live_log'));

print "<div><button type='submit' name='ACTION' value='clearlog'>" . L('clear_log') . "</button></div>";

print "<pre id='logbox' style='background:#000;color:#0f0;height:250px;overflow:auto;'>" . L('loading') . "</pre>";

my $js_log_load_failed = encode_json(L('log_load_failed'));
print <<EOF;
<script>
(function() {
    var logbox = document.getElementById('logbox');
    var logRequestInFlight = false;

    function fetchLogs() {
        if (!logbox) return;
        if (logRequestInFlight) return;
        logRequestInFlight = true;

        var xhr = new XMLHttpRequest();
        xhr.open('GET', window.location.pathname + '?ajax=log&_=' + Date.now(), true);
        xhr.timeout = 10000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            logRequestInFlight = false;

            if (xhr.status === 200) {
                logbox.textContent = xhr.responseText;
                logbox.scrollTop = logbox.scrollHeight;
            } else {
                logbox.textContent = $js_log_load_failed + xhr.status;
            }
        };
        xhr.onerror = function() {
            logRequestInFlight = false;
            logbox.textContent = $js_log_load_failed + 'network';
        };
        xhr.ontimeout = function() {
            logRequestInFlight = false;
            logbox.textContent = $js_log_load_failed + 'timeout';
        };
        xhr.send();
    }

    fetchLogs();
    setInterval(fetchLogs, 3000);
})();
</script>
EOF

&Header::closebox();

print "</form>";
&Header::closebigbox();
&Header::closepage();
