#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A linux based firewall                                         #
# Copyright (C) 2016  Alexander Marx alexander.marx@ipfire.org                #
#                                                                             #
# This program is free software you can redistribute it and/or modify         #
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.       #
#                                                                             #
#     Umberto Parma                                                           #
#                                                                             #
#                                                                             #
#    Version 2.0.2                                                            #
#                                                                             #
###############################################################################

use strict;
use warnings;
use CGI ();
use HTML::Entities qw(encode_entities);
use HTML::Template;
use Encode ();
require '/var/ipfire/general-functions.pl';
require '/var/ipfire/lang.pl';
require '/var/ipfire/captive-lib.pl';
my %visitor_languages = (en => 'English', de => 'Deutsch', es => 'Español', fr => 'Français', it => 'Italiano', nl => 'Nederlands', pl => 'Polski', ru => 'Русский', tr => 'Türkçe', zh => '简体中文', tw => '繁體中文');
# Match standard browser tags (zh-CN/zh-TW/en-US) and quality preferences.
my $visitor_language = Captive::ui_language();
my @preferences;
my $order = 0;
for my $item (split /,/, ($ENV{'HTTP_ACCEPT_LANGUAGE'} // '')) {
    next unless $item =~ /^\s*([A-Za-z][A-Za-z0-9_-]*)(?:\s*;\s*q=(0(?:\.\d+)?|1(?:\.0+)?))?\s*$/;
    my ($tag, $quality) = (lc($1), defined($2) ? 0+$2 : 1);
    $tag =~ tr/_/-/;
    my $code = $tag =~ /^zh-(?:tw|hk|mo|hant)(?:-|$)/ ? 'tw' : $tag =~ /^zh(?:-|$)/ ? 'zh' : (split /-/, $tag)[0];
    push @preferences, [$code, $quality, $order++] if $quality > 0 && exists $visitor_languages{$code};
}
if (@preferences) {
    @preferences = sort { $b->[1] <=> $a->[1] || $a->[2] <=> $b->[2] } @preferences;
    $visitor_language = $preferences[0][0];
} elsif (length($ENV{'HTTP_ACCEPT_LANGUAGE'} // '')) {
    $visitor_language = 'en';
}
$visitor_language = 'en' unless exists $visitor_languages{$visitor_language};
Captive::set_ui_language($visitor_language);


$CGI::POST_MAX = 16384;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = CGI->new;
Captive::fail('400 Bad Request', 'invalid_request') if $cgi->cgi_error;
my %params;
for my $key ($cgi->param) {
    my @values = $cgi->multi_param($key);
    Captive::fail('400 Bad Request', 'duplicate_field') unless @values == 1;
    $params{$key} = $values[0];
}
# Explicit visitor selection is independent of GUI and printed coupon language.
if (exists $visitor_languages{$params{'language'} // ''}) {
    $visitor_language = $params{'language'};
}
$visitor_language = 'en' unless exists $visitor_languages{$visitor_language};
Captive::set_ui_language($visitor_language);
my $state_lock = Captive::lock();
my (%settings, %net);
General::readhash('/var/ipfire/captive/settings', \%settings);
General::readhash('/var/ipfire/ethernet/settings', \%net);
# REMOTE_ADDR is set by Apache; never trust client-supplied forwarded headers.
my $ip = $ENV{'REMOTE_ADDR'} // '';
my $zone = Captive::zone($ip, \%settings, \%net);
Captive::fail('403 Forbidden', 'network_disabled') unless $zone;
my $url = Captive::safe_url($params{'redirect'});
my $error = '';
if (($params{'ACTION'} // '') eq 'SUBMIT') {
    Captive::fail('405 Method Not Allowed', 'post_required') unless ($ENV{'REQUEST_METHOD'} // '') eq 'POST';
    Captive::fail('403 Forbidden', 'invalid_csrf') unless Captive::check_csrf('portal', $params{'CSRF_TOKEN'});
    Captive::fail('429 Too Many Requests', 'too_many_attempts') unless Captive::attempt($ip);
    my $mac = Captive::arp_mac($ip, $net{"${zone}_DEV"});
    if (!$mac) {
        $error = Captive::tr('verify_device_failed');
    } else {
        my (%coupons, %clients);
        Captive::read_rows('/var/ipfire/captive/coupons', \%coupons);
        Captive::read_rows('/var/ipfire/captive/clients', \%clients);
        my ($duration, $code, $remark);
        if (($settings{'AUTH'} // '') eq 'COUPON') {
            $code = uc($params{'COUPON'} // '');
            $code =~ s/^\s+|\s+$//g;
            my ($key) = grep { ($coupons{$_}[1] // '') eq $code } keys %coupons;
            if (defined($key) && length($code) && length($code) <= 64 && Captive::duration($coupons{$key}[2])) {
                $duration = $coupons{$key}[2];
                $remark = $coupons{$key}[3] // '';
                delete $coupons{$key};
            } else { $error = Captive::tr('invalid_coupon'); }
        } elsif (($settings{'AUTH'} // '') eq 'TERMS') {
            if (($params{'TERMS'} // '') eq 'on' && Captive::duration($settings{'SESSION_TIME'})) {
                ($duration, $code, $remark) = ($settings{'SESSION_TIME'}, 'TERMS', '');
            } else { $error = Captive::tr('accept_terms'); }
        } else { $error = Captive::tr('auth_not_configured'); }
        if (!$error && defined($duration) && defined($code)) {
            # Keep one current binding for each IP or MAC, using the native CSV schema.
            delete $clients{$_} for grep { $clients{$_}[0] eq $mac || $clients{$_}[1] eq $ip } keys %clients;
            $clients{Captive::next_key(\%clients)} = [$mac, $ip, time(), $duration, $code, $remark];
            Captive::commit(\%coupons, \%clients);
            if (Captive::reload()) {
                General::log('Captive', "Access granted to $ip on $zone for $duration seconds");
                my $destination = Captive::post_auth_url($url);
                print "Status: 303 See Other\r\nLocation: $destination\r\nCache-Control: no-store\r\n\r\n";
                exit;
            }
            General::log('Captive', "Firewall reload failed after authorization for $ip");
            $error = Captive::tr('authorization_reload_failed');
        }
    }
}
my $language_options = join('', map {
    '<option value="' . $_ . '"' . ($_ eq $visitor_language ? ' selected' : '') . '>' . escape_html($visitor_languages{$_}) . '</option>'
} sort keys %visitor_languages);
my $tmpl = HTML::Template->new(filename => '/srv/web/ipfire/html/captive/template.html', die_on_bad_params => 0);
my $color = $settings{'COLOR'} // '#ff6600';
$color = '#ff6600' unless $color =~ /^#[0-9a-fA-F]{6}$/;
$tmpl->param(
    REDIRECT => escape_html($url),
    LANGUAGE => escape_html($visitor_language),
    HTML_LANGUAGE => escape_html($visitor_language eq 'tw' ? 'zh-Hant' : $visitor_language eq 'zh' ? 'zh-Hans' : $visitor_language),
    LANGUAGE_OPTIONS => $language_options,
    L_LANGUAGE => escape_html(Captive::tr('portal_language')),
    L_SWITCH => escape_html(Captive::tr('portal_switch')),
    L_COUPON_HINT => escape_html(Captive::tr('portal_coupon_hint')),
    CSRF_TOKEN => Captive::csrf('portal'),
    COUPON => ($settings{'AUTH'} // '') eq 'COUPON' ? 1 : 0,
    TITLE => escape_html($settings{'TITLE'} // 'IPFire Captive Portal'),
    COLOR => $color,
    ERROR => escape_html($error),
    L_HEADING => escape_html(Captive::tr(($settings{'AUTH'} // '') eq 'COUPON' ? 'portal_coupon' : 'portal_terms')),
    L_ACTIVATE => escape_html(Captive::tr('portal_activate')),
    L_GAIN_ACCESS => escape_html(Captive::tr('portal_gain_access')),
    L_AGREE_TERMS => escape_html(Captive::tr('portal_agree_terms')),
    TERMS => terms('terms.txt'),
    L_TERMS => escape_html(Captive::tr('terms1')),
    LOGO_URL => -s '/var/ipfire/captive/logo.dat' ? '/cgi-bin/logo.cgi' : '/assets/ipfire.png',
);
print "Cache-Control: no-store\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n";
print $tmpl->output;
sub terms {
    my ($name) = @_;
    open(my $fh, '<:raw', "/var/ipfire/captive/$name") or return '';
    my $text = do { local $/; <$fh> }; close $fh;
    $text = escape_html($text // '');
    $text =~ s/\n/<br>/g;
    return $text;
}

sub escape_html { return HTML::Entities::encode_entities($_[0] // '', q{<>&"'}); }
