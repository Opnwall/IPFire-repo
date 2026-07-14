#!/usr/bin/perl

use strict;
use warnings;
no warnings 'once';
use utf8;
use HTML::Entities qw(encode_entities);

require "/var/ipfire/general-functions.pl";
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

my $config_file = "/etc/sysconfig/ttyd";
my $service = "/etc/rc.d/init.d/ttyd";
my $sudo_cmd = "/usr/bin/sudo";
my %config = (
	TTYD_INTERFACE => "0.0.0.0",
	TTYD_PORT      => "7681",
	TTYD_SSH_USER  => "root",
	TTYD_SSH_HOST  => "127.0.0.1",
	TTYD_SSH_PORT  => "22",
);
my %settings = ();

if (open(my $fh, "<", $config_file)) {
	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^\s*(?:#|$)/;
		if ($line =~ /^\s*([A-Za-z0-9_]+)\s*=\s*"?([^"]*)"?\s*$/) {
			$config{$1} = $2;
		}
	}
	close($fh);
}

&Header::showhttpheaders();
&Header::getcgihash(\%settings);

my $action = $settings{'ACTION'} || "";
my $cmd_output = "";
my $show_output = 0;
my %post_actions = map { $_ => 1 } qw(start stop restart);

sub request_is_safe_for_action {
	return 1 if $action eq "";
	return 0 if (($ENV{'REQUEST_METHOD'} || "") ne "POST");

	my $host = $ENV{'HTTP_HOST'} || "";
	return 0 if $host eq "";

	my $seen_source_header = 0;
	foreach my $header ("HTTP_ORIGIN", "HTTP_REFERER") {
		my $value = $ENV{$header} || "";
		next if $value eq "";
		$seen_source_header = 1;
		return 0 if $value !~ m{^https?://\Q$host\E(?:/|$)}i;
	}

	return $seen_source_header;
}

sub service_running {
	return 0 unless -r "/run/ttyd.pid";
	open(my $fh, "<", "/run/ttyd.pid") or return 0;
	my $pid = <$fh>;
	close($fh);
	chomp $pid if defined $pid;
	return 0 unless defined $pid && $pid =~ /^\d+$/;
	return -d "/proc/$pid";
}

sub ttyd_tr {
	my ($key, $fallback) = @_;

	if (exists $Lang::tr{$key} && defined $Lang::tr{$key} && $Lang::tr{$key} ne "") {
		return $Lang::tr{$key};
	}

	my %zh = (
		'ttyd url'         => '链接地址',
		'ttyd target'      => 'SSH 目标',
		'ttyd status'      => '服务状态',
		'ttyd running'     => '运行中',
		'ttyd stopped'     => '已停止',
		'ttyd start'       => '启动',
		'ttyd stop'        => '停止',
		'ttyd restart'     => '重启',
		'ttyd refresh'     => '刷新',
		'ttyd command output' => '命令输出',
		'ttyd reject non post request' => '拒绝非 POST 请求',
		'ttyd reject unknown command' => '拒绝执行未知命令',
		'ttyd not running' => 'ttyd 未运行。请确认 ttyd 已安装、SSH 已启用，并且 IPFire WebUI 证书可用。',
	);

	my %tw = (
		'ttyd url'         => '連結地址',
		'ttyd target'      => 'SSH 目標',
		'ttyd status'      => '服務狀態',
		'ttyd running'     => '執行中',
		'ttyd stopped'     => '已停止',
		'ttyd start'       => '啟動',
		'ttyd stop'        => '停止',
		'ttyd restart'     => '重新啟動',
		'ttyd refresh'     => '重新整理',
		'ttyd command output' => '命令輸出',
		'ttyd reject non post request' => '拒絕非 POST 請求',
		'ttyd reject unknown command' => '拒絕執行未知命令',
		'ttyd not running' => 'ttyd 未執行。請確認 ttyd 已安裝、SSH 已啟用，並且 IPFire WebUI 憑證可用。',
	);

	if (($Lang::language || "") eq "tw" && exists $tw{$key}) {
		return $tw{$key};
	}

	if (($Lang::language || "") eq "zh" && exists $zh{$key}) {
		return $zh{$key};
	}

	return $fallback;
}

sub run_service_command {
	my ($command) = @_;
	my %allowed = map { $_ => 1 } qw(start stop restart status);
	return ttyd_tr("ttyd reject unknown command", "Rejected unknown command") . "\n" unless $allowed{$command};
	return `$sudo_cmd -n $service $command 2>&1`;
}

if ($post_actions{$action} && !request_is_safe_for_action()) {
	$cmd_output = ttyd_tr("ttyd reject non post request", "Rejected non-POST request");
	$show_output = 1;
	$action = "";
}

if ($action eq "start") {
	$cmd_output = run_service_command("start");
	$show_output = 1;
}
elsif ($action eq "stop") {
	$cmd_output = run_service_command("stop");
	$show_output = 1;
}
elsif ($action eq "restart") {
	$cmd_output = run_service_command("restart");
	$show_output = 1;
}

my $running = service_running();

my $host = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || $ENV{'SERVER_ADDR'} || "";
$host =~ s/:\d+$//;
my $url = "https://" . $host . ":" . ($config{TTYD_PORT} || "7681") . "/";
my $target = ($config{TTYD_SSH_USER} || "root") . "\@" . ($config{TTYD_SSH_HOST} || "127.0.0.1") . ":" . ($config{TTYD_SSH_PORT} || "22");

&Header::openpage("ttyd", 1, "");
&Header::openbigbox("100%", "left");

print <<'STYLE';
<style>
.ttyd-meta {
	width: 100%;
	border-collapse: collapse;
	margin-bottom: 14px;
}
.ttyd-meta td {
	border-top: 1px solid #d6d6d6;
	padding: 8px 10px;
}
.ttyd-meta td:first-child {
	width: 170px;
	font-weight: bold;
}
.ttyd-terminal {
	width: 100%;
	height: 63vh;
	min-height: 600px;
	border: 1px solid #222;
	background: #111;
}
.ttyd-warning {
	border: 1px solid #d6a600;
	background: #fff7d7;
	padding: 10px;
	margin-top: 12px;
}
.ttyd-output {
	background: #111;
	color: #f7f7f7;
	padding: 8px;
	white-space: pre-wrap;
}
.ttyd-status {
	display: inline-block;
	width: 10px;
	height: 10px;
	border-radius: 50%;
	margin-right: 6px;
}
.ttyd-status.running { background: #2ecc71; }
.ttyd-status.stopped { background: #e74c3c; }
.ttyd-actions {
	margin: 12px 0 4px 0;
}
</style>
STYLE

print "<form method='post'>\n";
print "<table class='ttyd-meta'>\n";
print "<tr><td>" . encode_entities(ttyd_tr("ttyd url", "Link URL")) . "</td><td><a href='" . encode_entities($url) . "' target='_blank'>" . encode_entities($url) . "</a></td></tr>\n";
print "<tr><td>" . encode_entities(ttyd_tr("ttyd target", "SSH target")) . "</td><td>" . encode_entities($target) . "</td></tr>\n";
print "<tr><td>" . encode_entities(ttyd_tr("ttyd status", "Service status")) . "</td><td>";
if ($running) {
	print "<span class='ttyd-status running'></span>" . encode_entities(ttyd_tr("ttyd running", "running"));
} else {
	print "<span class='ttyd-status stopped'></span>" . encode_entities(ttyd_tr("ttyd stopped", "stopped"));
}
print "</td></tr>\n";
print "</table>\n";

print "<div class='ttyd-actions'>\n";
print "<button type='submit' name='ACTION' value='start'>" . encode_entities(ttyd_tr("ttyd start", "Start")) . "</button> ";
print "<button type='submit' name='ACTION' value='stop'>" . encode_entities(ttyd_tr("ttyd stop", "Stop")) . "</button> ";
print "<button type='submit' name='ACTION' value='restart'>" . encode_entities(ttyd_tr("ttyd restart", "Restart")) . "</button> ";
print "<button type='submit' name='ACTION' value='refresh'>" . encode_entities(ttyd_tr("ttyd refresh", "Refresh")) . "</button>\n";
print "</div>\n";

if ($show_output) {
	print "<p><b>" . encode_entities(ttyd_tr("ttyd command output", "Command output")) . "</b></p>\n";
	print "<pre class='ttyd-output'>" . encode_entities($cmd_output) . "</pre>\n";
}

print "</form>\n";

if ($running) {
	print "<iframe class='ttyd-terminal' src='" . encode_entities($url) . "'></iframe>\n";
} else {
	print "<div class='ttyd-warning'>" . ttyd_tr("ttyd not running", "The terminal service is not running. Make sure ttyd is installed, SSH is enabled, and the IPFire WebUI certificate is available.") . "</div>\n";
}

&Header::closebigbox();
&Header::closepage();
