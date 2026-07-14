#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use HTML::Entities qw(encode_entities);

require "/var/ipfire/general-functions.pl";
require "${General::swroot}/header.pl";

my $config_file = "/etc/sysconfig/lucky";
my %config = (
	LUCKY_HTTP_PORT => "16601",
);

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

sub service_running {
	return 0 unless -r "/run/lucky.pid";
	open(my $fh, "<", "/run/lucky.pid") or return 0;
	my $pid = <$fh>;
	close($fh);
	chomp $pid if defined $pid;
	return 0 unless defined $pid && $pid =~ /^\d+$/;
	return -d "/proc/$pid";
}

sub file_first_line {
	my ($path) = @_;
	return "" unless -r $path;
	open(my $fh, "<", $path) or return "";
	my $line = <$fh> // "";
	close($fh);
	chomp $line;
	return $line;
}

sub lucky_tr {
	my ($key, $fallback) = @_;

	if (exists $Lang::tr{$key} && defined $Lang::tr{$key} && $Lang::tr{$key} ne "") {
		return $Lang::tr{$key};
	}

	my %zh = (
		'lucky url'         => '链接地址',
		'lucky version'     => '版本',
		'lucky status'      => '服务状态',
		'lucky running'     => '运行中',
		'lucky stopped'     => '已停止',
		'lucky open'        => '打开 Lucky',
		'lucky not running' => 'Lucky 未运行。请执行 <code>/etc/rc.d/init.d/lucky start</code> 后刷新本页。',
	);

	my %tw = (
		'lucky url'         => '連結地址',
		'lucky version'     => '版本',
		'lucky status'      => '服務狀態',
		'lucky running'     => '執行中',
		'lucky stopped'     => '已停止',
		'lucky open'        => '開啟 Lucky',
		'lucky not running' => 'Lucky 未執行。請執行 <code>/etc/rc.d/init.d/lucky start</code> 後重新整理本頁。',
	);

	if (($Lang::language || "") eq "tw" && exists $tw{$key}) {
		return $tw{$key};
	}

	if (($Lang::language || "") eq "zh" && exists $zh{$key}) {
		return $zh{$key};
	}

	return $fallback;
}

my $running = service_running();
my $host = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || $ENV{'SERVER_ADDR'} || "";
$host =~ s/:\d+$//;
my $url = "https://" . $host . ":" . ($config{LUCKY_HTTP_PORT} || "16601") . "/";
my $version = file_first_line("/opt/lucky/VERSION") || "v2.27.2";

&Header::showhttpheaders();
&Header::openpage("Lucky", 1, "");
&Header::openbigbox("100%", "left");

print <<'STYLE';
<style>
.lucky-meta {
	width: 100%;
	border-collapse: collapse;
	margin-bottom: 14px;
}
.lucky-meta td {
	border-top: 1px solid #d6d6d6;
	padding: 8px 10px;
}
.lucky-meta td:first-child {
	width: 170px;
	font-weight: bold;
}
.lucky-status-running {
	color: #178317;
	font-weight: bold;
}
.lucky-status-stopped {
	color: #a80000;
	font-weight: bold;
}
.lucky-actions {
	margin: 12px 0 16px 0;
}
.lucky-button {
	display: inline-block;
	padding: 7px 12px;
	background: #c92a2a;
	color: #fff !important;
	border: 1px solid #9f2020;
	text-decoration: none;
	font-weight: bold;
}
</style>
STYLE

print "<table class='lucky-meta'>\n";
print "<tr><td>" . encode_entities(lucky_tr("lucky url", "Link URL")) . "</td><td><a href='" . encode_entities($url) . "' target='_blank'>" . encode_entities($url) . "</a></td></tr>\n";
print "<tr><td>" . encode_entities(lucky_tr("lucky version", "Version")) . "</td><td>" . encode_entities($version) . "</td></tr>\n";
print "<tr><td>" . encode_entities(lucky_tr("lucky status", "Service status")) . "</td><td><span class='" . ($running ? "lucky-status-running" : "lucky-status-stopped") . "'>" . encode_entities($running ? lucky_tr("lucky running", "running") : lucky_tr("lucky stopped", "stopped")) . "</span></td></tr>\n";
print "</table>\n";

if ($running) {
	print "<div class='lucky-actions'><a class='lucky-button' href='" . encode_entities($url) . "' target='_blank'>" . encode_entities(lucky_tr("lucky open", "Open Lucky")) . "</a></div>\n";
} else {
	print "<p>" . lucky_tr("lucky not running", "Lucky is not running. Start it with <code>/etc/rc.d/init.d/lucky start</code>, then refresh this page.") . "</p>\n";
}

&Header::closebigbox();
&Header::closepage();
