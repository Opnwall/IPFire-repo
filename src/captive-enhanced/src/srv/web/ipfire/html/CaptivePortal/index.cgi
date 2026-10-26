#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A linux based firewall      									  #
# IPFire Captive Portal - Coupon Generator									  #
# Copyright (C) 2016  IPFire Team  <alexander.marx@ipfire.org>  			  #
#                                                                             #
#     Edited by Umberto Parma                                                 #
#                                                                             #
#                                                                             #
# This program is free software: you can redistribute it and/or modify        #
# it under the terms of the GNU General Public License as published by        #
# the Free Software Foundation, either version 3 of the License, or           #
# (at your option) any later version.                                         #
#                                                                             #
# This program is distributed in the hope that it will be useful,             #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
# GNU General Public License for more details.                                #
#                                                                             #
# You should have received a copy of the GNU General Public License           #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.   	  #          
#                                                                             #
#Versione del 18-10-2026 ora 09.13	version 1.0.8							  #
# Language files:															  #
#   /var/ipfire/ddon-lang/captive.languages/<ISO>.pl						  #
#																			  #
# Format:																	  #
#   key=value																  #
#																			  #
# Example:																	  #
#   title=IPFire Captive Portal Coupons										  #
#   login=Login																  #
#																			  #
# Coupons are saved in:														  #
#   /var/ipfire/captive/coupons												  #
#                                                                             #
###############################################################################

use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock);

use CGI ();
use Encode ();
require '/var/ipfire/general-functions.pl';
require '/var/ipfire/captive-lib.pl';
Captive::management();
my $state_lock = Captive::lock();
my $csrf_token = Captive::csrf('management');
use utf8;                        # Dice a Perl che il codice sorgente contiene caratteri UTF-8 (come 'giorno', 'ora', 'mese')
binmode(STDOUT, ":utf8");        # Istruisce Perl a sputare fuori l'HTML verso il b

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

my $COUPON_FILE  = "/var/ipfire/captive/coupons";
my $SETTING_FILE = "/var/ipfire/captive/settings";
my $IMAGE_FILE   = "/srv/web/ipfire/html/captive/assets/ipfire.png";
my $LANG_DIR     = "/var/ipfire/captive/languages";
my %SESSION_TIMES = (
    0        => "unlimited",
    3600     => "1_hour",
    14400    => "4_hours",
    28800    => "8_hours",
    43200    => "12_hours",
    86400    => "24_hours",
    604800   => "1_week",
    1209600  => "2_weeks",
    2592000  => "1_month",
    31536000 => "1_year",
);

# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------

sub html_escape {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}

sub url_decode {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ tr/+/ /;
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    return $s;
}

sub parse_form {
    $CGI::POST_MAX = 65536;
    $CGI::DISABLE_UPLOADS = 1;
    my $cgi = CGI->new;
    Captive::fail('400 Bad Request', 'invalid_request') if $cgi->cgi_error;
    my %p;
    for my $key ($cgi->param) {
        my @values = $cgi->multi_param($key);
        Captive::fail('400 Bad Request', 'duplicate_field') if @values != 1;
        $p{$key} = Encode::decode('UTF-8', $values[0], Encode::FB_CROAK);
    }
    return %p;
}

sub read_setting {
    my ($file) = @_;
    my %setting;

    return %setting unless -r $file;

    open(my $fh, '<:encoding(UTF-8)', $file) or return %setting;

    while (my $line = <$fh>) {
        chomp($line);
        $line =~ s/\r\z//;
        $line =~ s/^\x{FEFF}//;          # UTF-8 BOM
        $line =~ s/^\s+//;
        $line =~ s/\s+\z//;

        next if $line eq '';
        next if $line =~ /^[#;]/;

        my ($key, $value);

        # Accept the formats normally encountered in IPFire/config files:
        # key=value, key = value, key,value, key:value.
        if ($line =~ /^([^=,:]+?)\s*[=,:]\s*(.*)\z/) {
            ($key, $value) = ($1, $2);
		} elsif ($line =~ /^([^=,:]+?)\s*,\s*(.*)\z/) {
            ($key, $value) = ($1, $2);
        } elsif ($line =~ /^([^=,:]+?)\s*:\s*(.*)\z/) {
            ($key, $value) = ($1, $2);
        } else {
            next;
        }

        $key =~ s/^\s+//;
        $key =~ s/\s+\z//;
        $value =~ s/^\s+//;
        $value =~ s/\s+\z//;

        # Remove optional quotes around values.
        if (length($value) >= 2) {
            if (($value =~ /^"(.*)"\z/s) || ($value =~ /^'(.*)'\z/s)) {
                $value = $1;
            }
        }

        # Store keys case-insensitively. This also accepts SSID/company/
        # Translate/Traslate regardless of capitalization.
        $key = lc($key);
        $setting{$key} = $value;
    }

    close($fh);
    return %setting;
}

my %SETTING = read_setting($SETTING_FILE);

my $SSID = exists($SETTING{'ssid'}) ? $SETTING{'ssid'} : '';
my $COMPANY = exists($SETTING{'company'}) ? $SETTING{'company'} : '';
my @gui_languages = Captive::coupon_languages();
my %gui_settings;
General::readhash('/var/ipfire/main/settings', \%gui_settings);
my $LANG_CODE = Captive::coupon_language($SETTING{'translate'} || $SETTING{'traslate'} || 'en', $gui_settings{'LANGUAGE'}, \@gui_languages);
# Also accept the correctly-spelled "translate" key if present.
$LANG_CODE = $SETTING{'translate'} if exists($SETTING{'translate'}) && !$LANG_CODE;

$SSID =~ s/[\r\n]//g;
$COMPANY =~ s/[\r\n]//g;
$LANG_CODE =~ s/[^A-Za-z0-9_-]//g;
$LANG_CODE = 'en' if $LANG_CODE eq '';

# ---------------------------------------------------------------------------
# Translation 
# ---------------------------------------------------------------------------

my %I18N = ();

sub load_language {
    my ($code) = @_;
    my $file = "$LANG_DIR/captive.$code.txt";

    return unless -r $file;

    open(my $fh, '<:encoding(UTF-8)', $file) or return;

    while (my $line = <$fh>) {
        chomp($line);
        $line =~ s/\r\z//;
        next if $line =~ /^\s*#/ || $line =~ /^\s*\z/;

        my ($key, $value) = split(/\s*=\s*/, $line, 2);
        next unless defined($key) && defined($value);

        $key =~ s/^\s+//;
        $key =~ s/\s+\z//;
        $value =~ s/^\s+//;
        $value =~ s/\s+\z//;

        $I18N{$key} = $value if $key =~ /^[A-Za-z0-9_.-]+\z/;
    }

    close($fh);
}

load_language('en');
load_language($LANG_CODE);
Captive::set_ui_language($LANG_CODE);

sub t {
    my ($key) = @_;
	return $I18N{$key} if exists($I18N{$key});
}

# ---------------------------------------------------------------------------
# Authentication - web page login + cookie session
# ---------------------------------------------------------------------------

sub random_coupon { return Captive::code(); }
sub valid_remark { return Captive::remark($_[0]); }

sub read_coupons {
    my ($file)=@_;
    my %rows;
    Captive::read_rows($file, \%rows);
    # State uses UTF-8 bytes; HTML/PDF functions consume characters.
    for my $row (values %rows) {
        $row->[3] = Encode::decode('UTF-8', $row->[3] // '', Encode::FB_DEFAULT);
    }
    return %rows;
}
sub write_coupons {
    my ($file,$rows)=@_;
    my %encoded = map { $_ => [@{$rows->{$_}}] } keys %$rows;
    for my $row (values %encoded) { $row->[3] = Encode::encode('UTF-8', $row->[3] // ''); }
    Captive::write_rows($file, \%encoded);
}

sub coupon_exists {
    my ($coupons, $code) = @_;

    for my $key (keys %{$coupons}) {
        return 1 if defined($coupons->{$key}[1]) &&
                    $coupons->{$key}[1] eq $code;
    }

    return 0;
}

sub format_duration {
    my ($seconds) = @_;

    return t('unlimited') unless $seconds;

    if ($seconds % 31536000 == 0) {
        my $n = int($seconds / 31536000);
        return $n . ' ' . ($n == 1 ? t('year') : t('years'));
    }
    if ($seconds % 2592000 == 0) {
        my $n = int($seconds / 2592000);
        return $n . ' ' . ($n == 1 ? t('month') : t('months'));
    }
    if ($seconds % 604800 == 0) {
        my $n = int($seconds / 604800);
        return $n . ' ' . ($n == 1 ? t('week') : t('weeks'));
    }
    if ($seconds % 86400 == 0) {
        my $n = int($seconds / 86400);
        return $n . ' ' . ($n == 1 ? t('day') : t('days'));
    }
    if ($seconds % 3600 == 0) {
        my $n = int($seconds / 3600);
        return $n . ' ' . ($n == 1 ? t('hour') : t('hours'));
    }

    return $seconds . ' ' . ($seconds == 1 ? t('second') : t('seconds'));
}

# ---------------------------------------------------------------------------
# PDF helpers
# ---------------------------------------------------------------------------

# Convert UTF-8 text to a close WinAnsi representation suitable for
# PDF built-in Helvetica. This covers the usual Western European languages.
sub make_pdf {
    my ($rows)=@_;
    require '/var/ipfire/captive-pdf.pl';
    return CaptivePDF::generate(
        coupons => $rows, title => t('pdf_title'), company => $COMPANY, ssid => $SSID,
        labels => {company => t('company_prefix'), ssid => t('ssid_prefix'),
                   validity => t('valid_until'), remark => t('note_prefix'), empty => t('no_coupons')},
        duration => \&format_duration,
    );
}

my %params = parse_form();
my $action = $params{'ACTION'} || '';
if ($action ne '') {
    Captive::fail('405 Method Not Allowed', 'post_required') unless ($ENV{'REQUEST_METHOD'} // '') eq 'POST';
    Captive::fail('403 Forbidden', 'invalid_csrf')
        unless Captive::check_csrf('management', $params{'CSRF_TOKEN'});
}

# ---------------------------------------------------------------------------
# Refresh values from /var/ipfire/captive/setting for every request.
# ---------------------------------------------------------------------------

%SETTING = read_setting($SETTING_FILE);
$SSID = exists($SETTING{'ssid'}) ? $SETTING{'ssid'} : '';
$COMPANY = exists($SETTING{'company'}) ? $SETTING{'company'} : '';
$LANG_CODE = Captive::coupon_language($SETTING{'translate'} || $SETTING{'traslate'} || 'en', $gui_settings{'LANGUAGE'}, \@gui_languages);

$SSID =~ s/[\r\n]//g;
$COMPANY =~ s/[\r\n]//g;
$LANG_CODE =~ s/[^A-Za-z0-9_-]//g;
$LANG_CODE = 'en' if $LANG_CODE eq '';



load_language('en');
load_language($LANG_CODE);
Captive::set_ui_language($LANG_CODE);

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

if ($action eq 'export-coupons') {
    my %coupons = read_coupons($COUPON_FILE);
    close($state_lock); # Font embedding must not hold the global state lock.
    my $pdf = make_pdf(\%coupons);

    # MODIFICA DA APPLICARE: forza STDOUT in modalità binaria/grezza per il PDF
    binmode(STDOUT, ":raw");

    print "Cache-Control: no-store\r\nContent-Type: application/pdf\r\n";
    print "Content-Disposition: attachment; filename=captive-portal-coupons.pdf\r\n";
    print "Content-Length: " . length($pdf) . "\r\n";
    print "\r\n";
    print $pdf;
    exit;
}

my $message = '';
my $error = '';

if ($action eq 'generate-coupons') {
    my $count = $params{'COUNT'} // '';
    my $expiry = $params{'SESSION_TIME'};
    my $remark = $params{'REMARK'} // '';
    if ($count !~ /^(?:[1-9][0-9]?|100)\z/) { $error = t('invalid_count'); }
    elsif (!Captive::duration($expiry)) { $error = t('invalid_duration'); }
    elsif (!valid_remark($remark)) { $error = t('invalid_note'); }
    else {
        my %coupons = read_coupons($COUPON_FILE);
        for (1..$count) {
            my $code;
            do { $code = random_coupon(); } while coupon_exists(\%coupons, $code);
            $coupons{Captive::next_key(\%coupons)} = [time(), $code, $expiry, $remark];
        }
        write_coupons($COUPON_FILE, \%coupons);
        General::log('Captive', "Administrator generated $count coupons") if defined(&General::log);
        $message = "$count " . t('generated_saved');
    }
}

# ---------------------------------------------------------------------------
# HTML interface
# ---------------------------------------------------------------------------

my %coupons = read_coupons($COUPON_FILE);

print "Cache-Control: no-store\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n";

print <<"HTML";
<!doctype html>
	<html lang="@{[html_escape($LANG_CODE)]}">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width,initial-scale=1">
		<title>@{[html_escape(t('title'))]}</title>
		<style>
			body{margin:0;background:#f2f2f2;font-family:Arial,Helvetica,sans-serif;color:#222}
			.container{max-width:950px;margin:30px auto;padding:0 15px}
			.box{background:#fff;border:1px solid #ccc;border-radius:8px;padding:24px;margin-bottom:20px}
			h1{margin-top:0}
			label{display:block;font-weight:bold;margin:12px 0 5px}
			input,select{font-size:16px;padding:8px;box-sizing:border-box}
			input[type=text],input[readonly],select{width:100%;max-width:420px}
			input[readonly]{background:#f0f0f0;color:#222;border:1px solid #999;font-weight:600}
			button{padding:10px 18px;font-size:16px;cursor:pointer}
			table{width:100%;border-collapse:collapse;margin-top:15px}
			th,td{border:1px solid #ddd;padding:8px;text-align:left}
			th{background:#eee}
			.ok{padding:12px;background:#e5f6e5;border:1px solid #8bc48b;margin-bottom:15px}
			.err{padding:12px;background:#ffe5e5;border:1px solid #d88;margin-bottom:15px}
			.code{font-weight:bold;font-size:20px;letter-spacing:2px}
			.small{color:#666;font-size:13px}
			.actions{text-align:right;margin-top:20px}
			.topbar{display:flex;justify-content:space-between;align-items:center;margin-bottom:15px}
			.logout{font-size:14px}
		</style>
	</head>
	<body>
		<div class="container">
		<div class="box">
		<div class="topbar">
			<h1>@{[html_escape(t('title'))]}</h1>
<a href="/cgi-bin/captive.cgi">IPFire Captive Portal</a>
		</div>

HTML

if ($message) {
    print '<div class="ok">' . html_escape($message) . '</div>';
}

if ($error) {
    print '<div class="err">' . html_escape($error) . '</div>';
}

print <<"HTML";
	<form method="post" action="@{[html_escape($ENV{'SCRIPT_NAME'} || '')]}">
        <input type="hidden" name="CSRF_TOKEN" value="$csrf_token">
		<input type="hidden" name="ACTION" value="generate-coupons">

		<label for="SESSION_TIME">@{[html_escape(t('coupon_validity'))]}</label>
		<select id="SESSION_TIME" name="SESSION_TIME">
HTML

for my $seconds (sort { $a <=> $b } keys %SESSION_TIMES) {
    print '<option value="' . html_escape($seconds) . '">' .
          html_escape(t($SESSION_TIMES{$seconds})) . "</option>\n";
}

print <<"HTML";
	</select>

	<label for="COUNT">@{[html_escape(t('coupon_count'))]}</label>
	<select id="COUNT" name="COUNT">
HTML

for my $n (1,2,3,4,5,6,7,8,9,10,20,50,100) {
    print "<option value=\"$n\">$n</option>\n";
}

print <<"HTML";
		</select>

		<label for="REMARK">@{[html_escape(t('note'))]}</label>
			<input id="REMARK" type="text" name="REMARK" maxlength="200"
				   placeholder="@{[html_escape(t('note_optional'))]}">

			<label for="SSID">@{[html_escape(t('ssid'))]}</label>
			<input id="SSID" name="SSID_DISPLAY" type="text"
				   value="@{[html_escape($SSID)]}" readonly aria-readonly="true">

			<label for="COMPANY">@{[html_escape(t('company'))]}</label>
			<input id="COMPANY" name="COMPANY_DISPLAY" type="text"
				   value="@{[html_escape($COMPANY)]}" readonly aria-readonly="true">

			<div class="actions">
			<button type="submit">@{[html_escape(t('generate'))]}</button>
			</div>
		</form>
	</div>

	<div class="box">
		<h2>@{[html_escape(t('existing_coupons'))]}</h2>
HTML

if (%coupons) {
    print "<table>\n";
    print "<tr><th>" . html_escape(t('coupon')) . "</th>" .
          "<th>" . html_escape(t('validity')) . "</th>" .
          "<th>" . html_escape(t('note')) . "</th>" .
          
          "</tr>\n";

    for my $key (sort { $coupons{$a}[0] <=> $coupons{$b}[0] } keys %coupons) {
        my $code = $coupons{$key}[1] // '';
        my $expiry = $coupons{$key}[2] // 0;
        my $remark = $coupons{$key}[3] // '';

        print "<tr>";
        print '<td class="code">' . html_escape($code) . "</td>";
        print '<td>' . html_escape(format_duration($expiry)) . "</td>";
        print '<td>' . html_escape($remark) . "</td>";
        
        print "</tr>\n";
    }

    print "</table>\n";

    print <<"HTML";
	<div class="actions">
		<form method="get" action="/CaptivePortal/export.cgi">
			<button type="submit">@{[html_escape(t('export_pdf'))]}</button>
		</form>
	</div>
HTML
} else {
    print '<p>' . html_escape(t('no_coupons')) . "</p>\n";
}

print <<"HTML";
			</div>
		</div>
	</body>
</html>
HTML

exit 0;
