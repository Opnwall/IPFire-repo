#!/usr/bin/perl
use strict;
use utf8;
use Encode qw(decode FB_CROAK);
use CGI::Carp qw(fatalsToBrowser carpout);
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json);

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my %settings = ();
my %checked  = ();
my %selected = ();

# ====== 可调整路径 ======
my $service       = "/etc/init.d/sing-box";
my $singbox_bin   = "/usr/local/bin/sing-box";
my $singbox_conf  = "/usr/local/etc/sing-box/config.json";
my $singbox_log   = "/var/log/sing-box.log";
my $sudo_cmd      = "/usr/bin/sudo";
# ========================

my %fallback = (
    page_title => 'Sing-Box',
    service_status => 'Service Status',
    status => 'Status',
    running => 'Running',
    stopped => 'Stopped',
    start => 'Start',
    stop => 'Stop',
    restart => 'Restart',
    config_file => 'Configuration File',
    save_config => 'Save Configuration',
    log_output => 'Log Output',
    clear_log => 'Clear Log',
    no_log_file => 'No log file available.',
    clear_log_failed => 'Failed to clear log',
    command_failed => 'Unable to execute command',
    save_write_failed => 'Save failed: unable to write configuration file',
    write_config_failed => 'Unable to write configuration file',
    temp_config_failed => 'Unable to create temporary configuration file',
    config_check_failed => 'Configuration validation failed',
    save_check_failed => 'Save failed: configuration validation did not pass',
    config_saved => 'Configuration saved',
    save_no_config => 'Save failed: no configuration content received',
    request_rejected => 'Request rejected: management actions must come from the current Web UI',
    log_cleared => 'Log cleared',
    log_load_failed => 'Log loading failed, HTTP status: ',
);

my %fallback_zh = (
    page_title => 'Sing-Box',
    service_status => '服务状态',
    status => '状态',
    running => '运行中',
    stopped => '已停止',
    start => '启动',
    stop => '停止',
    restart => '重启',
    config_file => '配置文件',
    save_config => '保存配置',
    log_output => '日志输出',
    clear_log => '清空日志',
    no_log_file => '暂无日志文件。',
    clear_log_failed => '清空日志失败',
    command_failed => '无法执行命令',
    save_write_failed => '保存失败：无法写入配置文件',
    write_config_failed => '无法写入配置文件',
    temp_config_failed => '无法创建临时配置文件',
    config_check_failed => '配置校验失败',
    save_check_failed => '保存失败：配置校验未通过',
    config_saved => '配置已保存',
    save_no_config => '保存失败：未收到配置内容',
    request_rejected => '请求被拒绝：管理操作必须来自当前 Web 界面',
    log_cleared => '日志已清空',
    log_load_failed => '日志加载失败，HTTP 状态: ',
);

my %fallback_tw = (
    page_title => 'Sing-Box',
    service_status => '服務狀態',
    status => '狀態',
    running => '執行中',
    stopped => '已停止',
    start => '啟動',
    stop => '停止',
    restart => '重新啟動',
    config_file => '設定檔',
    save_config => '儲存設定',
    log_output => '記錄輸出',
    clear_log => '清除記錄',
    no_log_file => '沒有記錄檔。',
    clear_log_failed => '清除記錄失敗',
    command_failed => '無法執行命令',
    save_write_failed => '儲存失敗：無法寫入設定檔',
    write_config_failed => '無法寫入設定檔',
    temp_config_failed => '無法建立暫存設定檔',
    config_check_failed => '設定驗證失敗',
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

# AJAX 日志接口
my $is_ajax_log = (
    (defined $settings{'ajax'} && $settings{'ajax'} eq 'log') ||
    (($ENV{'QUERY_STRING'} || '') =~ /(?:^|&)ajax=log(?:&|$)/)
);

if ($is_ajax_log) {
    print "Content-Type: text/plain; charset=UTF-8\n";
    print "Cache-Control: no-cache, no-store, must-revalidate\n";
    print "Pragma: no-cache\n";
    print "Expires: 0\n\n";

    if (-e $singbox_log && open(my $log_fh, "-|", "tail", "-n", "100", $singbox_log)) {
        local $/;
        my $log_content = <$log_fh>;
        close($log_fh);
        $log_content = strip_ansi($log_content);
        print $log_content;
    } else {
        print L('no_log_file') . "\n";
    }
    exit;
}

&Header::showhttpheaders();

my $action      = $settings{'ACTION'} || '';
my $cmd_output  = '';
my $show_output = 0;

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

sub decode_post_utf8 {
    my ($value) = @_;
    return '' unless defined $value;

    my $decoded = $value;
    eval {
        $decoded = decode('UTF-8', $value, FB_CROAK);
    };
    return $decoded;
}

sub run_service_command {
    my ($command) = @_;
    return run_command($sudo_cmd, "-n", $service, $command);
}

sub clear_log_file {
    my $fh;
    if (!open($fh, ">", $singbox_log)) {
        return L('clear_log_failed') . ": $!";
    }
    close($fh);
    return '';
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

sub write_config_file {
    my ($conf_text) = @_;
    my $fh;
    if (!open($fh, ">:encoding(UTF-8)", $singbox_conf)) {
        return (0, L('write_config_failed') . ": $!");
    }

    print $fh $conf_text;
    if (!close($fh)) {
        return (0, L('save_write_failed'));
    }

    return (1, '');
}

sub validate_config_text {
    my ($conf_text) = @_;

    my $tmp_dir = tempdir("singbox_check_XXXXXX", TMPDIR => 1, CLEANUP => 1);
    my $tmp_conf = "$tmp_dir/config.json";

    my $fh;
    if (!open($fh, ">:encoding(UTF-8)", $tmp_conf)) {
        return (0, L('temp_config_failed'));
    }
    print $fh $conf_text;
    close($fh);

    my $out = run_command($singbox_bin, "check", "-C", $tmp_dir);
    my $code = $? >> 8;

    if ($code == 0) {
        return (1, normalize_command_output($out));
    }

    return (0, normalize_command_output($out || L('config_check_failed')));
}

 # ====== 保存配置 / 服务控制 ======
if (!request_is_safe_for_action()) {
    $cmd_output  = L('request_rejected');
    $show_output = 1;
}
elsif ($action eq 'saveconf') {
    if (defined $settings{'CONF'}) {
        my $conf_text = decode_post_utf8($settings{'CONF'});

        my ($ok, $check_out) = validate_config_text($conf_text);
        if (!$ok) {
            $cmd_output  = L('save_check_failed') . "\n" . $check_out;
            $show_output = 1;
        } else {
            my ($saved, $save_out) = write_config_file($conf_text);
            if ($saved) {
                $cmd_output  = L('config_saved');
                $show_output = 1;
            } else {
                $cmd_output  = normalize_command_output($save_out);
                $show_output = 1;
            }
        }
    } else {
        $cmd_output  = L('save_no_config');
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
.config-wrap {
    position: relative;
}
.config-editor {
    position: relative;
    background: #111;
    border: 1px solid #666;
    box-sizing: border-box;
    min-height: 220px;
}
.config-highlight {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    margin: 0;
    padding: 8px;
    overflow: auto;
    white-space: pre;
    overflow-wrap: normal;
    word-break: normal;
    font-family: monospace;
    font-size: 14px;
    line-height: 1.4;
    letter-spacing: normal;
    box-sizing: border-box;
    color: #ddd;
    pointer-events: none;
    tab-size: 4;
}
.editor-toolbar {
    margin-bottom: 8px;
}
.config-textarea {
    position: relative;
    z-index: 2;
    width: 100%;
    min-height: 220px;
    margin: 0;
    padding: 8px;
    border: 0;
    outline: none;
    resize: vertical;
    background: transparent;
    color: transparent;
    caret-color: #ffffff;
    font-family: monospace;
    font-size: 14px;
    line-height: 1.4;
    letter-spacing: normal;
    overflow: auto;
    tab-size: 4;
    box-sizing: border-box;
}
.config-textarea::selection {
    background: rgba(173, 216, 230, 0.35);
    color: transparent;
}
.status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
    vertical-align: middle;
}
.status-dot.running {
    background: #2ecc71;
}
.status-dot.stopped {
    background: #e74c3c;
}
.config-highlight .json-key {
    color: #79c0ff;
}
.config-highlight .json-string {
    color: #a5d6ff;
}
.config-highlight .json-number {
    color: #f2cc60;
}
.config-highlight .json-bool {
    color: #ff7b72;
}
.config-highlight .json-null {
    color: #ff7b72;
}
</style>
EOF
&Header::openbigbox('100%', 'left', '', '');

print "<form method='post'>";

# ====== 服务状态 ======
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
print "<button type='submit' name='ACTION' value='restart'>" . L('restart') . "</button>";

if ($show_output) {
    print "<br><br><pre style='color:#ff3333;background:#111;padding:5px;box-sizing:border-box;margin:0;white-space:pre-wrap;'>";
    print &Header::escape($cmd_output);
    print "</pre>";
}

&Header::closebox();

# ====== 配置文件 ======
&Header::openbox('100%', 'left', L('config_file'));

print "<div class='editor-toolbar'>";
print "<button type='submit' name='ACTION' value='saveconf'>" . L('save_config') . "</button>";
print "</div>";

my $conf_content = '';
if (-e $singbox_conf) {
    if (open(my $fh, "<:raw", $singbox_conf)) {
        local $/;
        $conf_content = <$fh>;
        close($fh);
        eval {
            $conf_content = decode('UTF-8', $conf_content, FB_CROAK);
        };
    } else {
        if (open(my $fh, "<", $singbox_conf)) {
            local $/;
            $conf_content = <$fh>;
            close($fh);
        }
    }
}

print "<div class='config-wrap'>";
print "<div class='config-editor'>";
print "<pre id='json-preview' class='config-highlight'></pre>";
print "<textarea id='conf-editor' class='config-textarea' name='CONF' wrap='off' oninput='updateJsonPreview()' onscroll='syncJsonScroll()' spellcheck='false'>";
print &Header::escape($conf_content);
print "</textarea>";
print "</div>";
print "</div>";

&Header::closebox();

# ====== 日志输出 ======
&Header::openbox('100%', 'left', L('log_output'));

print "<div style='margin-bottom:8px;'><button type='submit' name='ACTION' value='clearlog'>" . L('clear_log') . "</button></div>";

print "<pre id='logbox' style='background:#000;color:#0f0;height:220px;overflow:auto;width:100%;box-sizing:border-box;margin:0;white-space:pre-wrap;'>";

if (-e $singbox_log) {
    if (open(my $log_fh, "-|", "tail", "-n", "100", $singbox_log)) {
        local $/;
        my $log_content = <$log_fh>;
        close($log_fh);
        $log_content = strip_ansi($log_content);
        print &Header::escape($log_content);
    }
} else {
    print L('no_log_file');
}

print "</pre>";

my $js_log_load_failed = encode_json(L('log_load_failed'));
print <<EOF;
<script>
(function() {
    var logbox = document.getElementById('logbox');
    var logRequestInFlight = false;

    function scrollLogToBottom() {
        if (logbox) {
            logbox.scrollTop = logbox.scrollHeight;
        }
    }

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
                scrollLogToBottom();
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

    scrollLogToBottom();
    fetchLogs();
    setInterval(fetchLogs, 3000);
})();
</script>
EOF

&Header::closebox();

print "</form>";

&Header::closebigbox();

print <<'EOF';
<script>
function escapeHtml(text) {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function highlightJson(text) {
    const escaped = escapeHtml(text);
    return escaped.replace(
        /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"\s*:?)|(\btrue\b|\bfalse\b)|(\bnull\b)|(-?\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?)/g,
        function(match) {
            let cls = 'json-number';
            if (/^".*":$/.test(match)) {
                cls = 'json-key';
            } else if (/^"/.test(match)) {
                cls = 'json-string';
            } else if (/true|false/.test(match)) {
                cls = 'json-bool';
            } else if (/null/.test(match)) {
                cls = 'json-null';
            }
            return '<span class="' + cls + '">' + match + '</span>';
        }
    );
}

function updateJsonPreview() {
    var editor = document.getElementById('conf-editor');
    var preview = document.getElementById('json-preview');
    if (!editor || !preview) return;

    var text = editor.value;
    if (text.length === 0) {
        preview.innerHTML = '<br>';
    } else {
        preview.innerHTML = highlightJson(text) + '<span>\u200b</span>';
    }

    syncJsonScroll();
}

function syncJsonScroll() {
    var editor = document.getElementById('conf-editor');
    var preview = document.getElementById('json-preview');
    if (!editor || !preview) return;

    preview.scrollTop = editor.scrollTop;
    preview.scrollLeft = editor.scrollLeft;
}

window.addEventListener('DOMContentLoaded', function() {
    updateJsonPreview();
    syncJsonScroll();
});
</script>
EOF

&Header::closepage();
