# Shared safety functions for IPFire captive enhancement. GPL-3.0-or-later.
package Captive;
use strict;
use warnings;
use utf8;
use Encode ();
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw(tempfile);
use Digest::SHA qw(hmac_sha256_hex);
use JSON::PP;
use Socket qw(inet_aton);
our $BASE = '/var/ipfire/captive';

our $ADDON_DIR = '/var/ipfire/addon-lang';
our $UI_LANGUAGE;
my %message_cache;
sub set_ui_language { $UI_LANGUAGE = $_[0]; }
sub ui_language {
    return $UI_LANGUAGE if defined $UI_LANGUAGE;
    my %main;
    if (-r '/var/ipfire/main/settings') {
        require '/var/ipfire/general-functions.pl';
        General::readhash('/var/ipfire/main/settings', \%main);
    }
    $UI_LANGUAGE = $main{'LANGUAGE'} || 'en';
    return $UI_LANGUAGE;
}
sub tr {
    my ($key) = @_;
    my $code = ui_language();
    $code = 'en' unless $code =~ /^[a-z]{2}(?:[-_][A-Za-z0-9]+)*\z/;
    my $cache_key = "$ADDON_DIR|$code";
    unless (exists $message_cache{$cache_key}) {
        # Isolate our native addon entries; never clear or replace core strings.
        local %Lang::tr = ();
        for my $language ('en', $code eq 'en' ? () : $code) {
            my $file = "$ADDON_DIR/captive-enhanced.$language.pl";
            do $file if -r $file;
        }
        $message_cache{$cache_key} = { %Lang::tr };
    }
    my $value = $message_cache{$cache_key}{'captive enhanced ' . $key};
    # A missing resource must still produce a nonempty error, never grant access.
    return defined($value) && length($value) ? $value : $key;
}
sub fail {
    my ($status, $key) = @_;
    my $message = Captive::tr($key);
    binmode(STDOUT, ':raw');
    print "Status: $status\r\nContent-Type: text/plain; charset=UTF-8\r\nCache-Control: no-store\r\n\r\n$message\n";
    exit;
}
sub random_hex {
    my ($n) = @_;
    open(my $fh, '<:raw', '/dev/urandom') or die 'Cannot open secure random source';
    my $data = '';
    while (length($data) < $n) {
        my $read = read($fh, my $part, $n - length($data));
        die 'Secure random source failed' unless defined($read) && $read > 0;
        $data .= $part;
    }
    close $fh;
    return uc unpack('H*', $data);
}
sub code { return random_hex(8); } # 64-bit, easy to type, no rand fallback
sub lock {
    sysopen(my $fh, "$BASE/.state.lock", O_RDWR) or die 'Cannot open captive lock';
    flock($fh, LOCK_EX) or die 'Cannot lock captive state';
    recover();
    return $fh; # Keep this handle alive for the complete transaction and reload.
}
sub atomic_text {
    my ($path, $data, $mode) = @_;
    die 'Invalid state path' unless $path =~ m{^\Q$BASE\E/[a-zA-Z0-9_.-]+$};
    my ($fh, $tmp) = tempfile('.write-XXXXXXXX', DIR => $BASE, UNLINK => 0);
    binmode($fh, ':raw');
    eval {
        print {$fh} $data or die 'Cannot write state';
        close($fh) or die 'Cannot close state';
        chown((stat($BASE))[4,5], $tmp) == 1 or die 'Cannot set state owner';
        chmod($mode // 0640, $tmp) or die 'Cannot set state permissions';
        rename($tmp, $path) or die 'Cannot replace state';
    };
    if ($@) { my $e = $@; unlink $tmp; die $e; }
}
# The core writehash skips keys ending in any-character + y, including company.
# Keep native key=value syntax but skip only actual CGI coordinate fields.
sub write_settings {
    my ($path,$settings)=@_;
    my $data='';
    for my $key (sort keys %$settings) {
        next if $key eq '__CGI__' || $key =~ /^ACTION/ || $key =~ /\.[xy]\z/;
        die 'Invalid settings key' unless $key =~ /^[A-Za-z0-9_-]+\z/;
        my $value=defined($settings->{$key}) ? $settings->{$key} : '';
        die 'Invalid settings value' if $value =~ /[\r\n\x00]/;
        $value="'$value'" if $value =~ / /;
        $data.="$key=$value\n";
    }
    atomic_text($path,$data);
}
sub read_rows {
    my ($path, $hash) = @_;
    %$hash = ();
    return unless -e $path;
    open(my $fh, '<:raw', $path) or die 'Cannot read captive state';
    while (<$fh>) {
        chomp;
        my ($key, @fields) = split /,/, $_, -1;
        next unless defined($key) && $key =~ /^\d+\z/;
        $hash->{$key} = \@fields;
    }
    close $fh;
}
sub rows_text {
    my ($hash) = @_;
    my $out = '';
    for my $key (sort {$a <=> $b} keys %$hash) {
        die 'Invalid row ID' unless $key =~ /^\d+\z/;
        my @fields = map { defined($_) ? $_ : '' } @{$hash->{$key}};
        die 'Invalid CSV field' if grep { /[,\r\n\x00]/ } @fields;
        $out .= join(',', $key, @fields) . "\n";
    }
    return $out;
}
sub write_rows { my ($path, $hash) = @_; atomic_text($path, rows_text($hash)); }
# Write-ahead journal: all cooperating writers recover it under the same lock.
# A process crash between the two renames must not enable a second redemption.
sub commit {
    my ($coupons, $clients) = @_;
    my $journal = { coupons => rows_text($coupons), clients => rows_text($clients) };
    atomic_text("$BASE/.transaction", JSON::PP->new->encode($journal), 0600);
    recover();
}
sub recover {
    return unless -e "$BASE/.transaction";
    open(my $fh, '<:raw', "$BASE/.transaction") or die 'Cannot read transaction';
    my $json = do { local $/; <$fh> }; close $fh;
    my $data = JSON::PP->new->decode($json);
    die 'Invalid transaction' unless ref($data) eq 'HASH' && defined($data->{coupons}) && defined($data->{clients});
    atomic_text("$BASE/coupons", $data->{coupons});
    atomic_text("$BASE/clients", $data->{clients});
    unlink("$BASE/.transaction") or die 'Cannot finish transaction';
}
sub next_key { my ($h)=@_; my $n=1; $n++ while exists $h->{$n}; return $n; }
sub csrf {
    my ($scope, $stamp) = @_;
    $stamp //= time();
    open(my $fh, '<:raw', "$BASE/.csrf-key") or die 'Cannot read CSRF key';
    my $secret = do { local $/; <$fh> }; close $fh;
    die 'Invalid CSRF key' unless length($secret) >= 64;
    return $stamp . '.' . hmac_sha256_hex(join('|', $scope, $ENV{REMOTE_USER} // '', $ENV{REMOTE_ADDR} // '', $stamp), $secret);
}
sub check_csrf {
    my ($scope, $token) = @_;
    return 0 unless defined($token) && $token =~ /^(\d{10})\.([a-f0-9]{64})\z/;
    my $stamp = $1;
    return 0 if $stamp > time()+30 || time()-$stamp > 3600;
    my $expected = csrf($scope, $stamp);
    my $diff = length($expected) ^ length($token);
    $diff |= ord(substr($expected,$_,1)) ^ ord(substr($token,$_,1)) for 0..length($expected)-1;
    return $diff == 0;
}
sub management {
    fail('403 Forbidden', 'admin_https_required')
        unless ($ENV{REMOTE_USER} // '') eq 'admin' && ($ENV{HTTPS} // '') eq 'on';
}
sub ipv4 {
    my ($ip) = @_;
    return 0 unless defined($ip) && $ip =~ /^\d{1,3}(?:\.\d{1,3}){3}\z/;
    return 0 if grep { $_ > 255 || ($_ ne '0' && /^0/) } split /\./, $ip;
    return 1;
}
sub valid_mac {
    my ($mac)=@_;
    return defined($mac) && $mac =~ /^(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\z/i && $mac !~ /^(?:00:){5}00\z/ && !(hex(substr($mac,0,2)) & 1);
}
sub zone {
    my ($ip, $settings, $net) = @_;
    return '' unless ipv4($ip);
    my $address = unpack('N', inet_aton($ip));
    for my $zone ('GREEN', 'BLUE') {
        next unless ($settings->{"ENABLE_$zone"} // '') eq 'on' && $net->{"${zone}_DEV"};
        my ($gw,$mask) = @{$net}{"${zone}_ADDRESS", "${zone}_NETMASK"};
        next unless ipv4($gw) && ipv4($mask);
        my $m = unpack('N', inet_aton($mask));
        my $network = unpack('N', inet_aton($gw)) & $m;
        next unless ($address & $m) == $network;
        next if $ip eq $gw || $address == $network || $address == ($network | (~$m & 0xffffffff));
        return $zone;
    }
    return '';
}
sub arp_mac {
    my ($ip, $dev) = @_;
    open(my $fh, '<', '/proc/net/arp') or die 'Cannot read ARP table';
    while (<$fh>) {
        my ($address,$type,$flags,$mac,$mask,$device) = split;
        next unless $address eq $ip && $device eq $dev && $flags =~ /^0x[0-9a-f]+\z/i && (hex($flags) & 2);
        if (valid_mac($mac)) { close $fh; return lc $mac; }
    }
    close $fh; return '';
}
sub duration { my ($v)=@_; return defined($v) && $v =~ /^(?:0|3600|14400|28800|43200|86400|604800|1209600|2592000|31536000)\z/; }
sub remark { my ($v)=@_; return defined($v) && length($v)<=200 && $v !~ /[,\r\n\x00-\x1f\x7f]/; }
sub safe_url {
    my ($url) = @_;
    return 'http://www.ipfire.org/' unless defined($url) && length($url)<=2048 && $url !~ /[\x00-\x20\x7f<>"'\\]/ && $url =~ m{^https?://[a-zA-Z0-9\[\].:-]+(?:[/?#]|$)}i;
    return $url;
}
# Always start a new HTTPS connection after either authentication method.
# Returning to an intercepted HTTP URL can reuse its pre-authentication DNAT
# mapping and display the portal again. Never use an untrusted return URL here.
sub post_auth_url {
    return 'https://www.bing.com/';
}
# Token bucket per source, persistent under the shared lock, bounded by expiry.
sub attempt {
    my ($ip) = @_;
    my %rates;
    read_rows("$BASE/.attempts", \%rates);
    my $now=time();
    delete $rates{$_} for grep { $now - $rates{$_}[1] > 600 } keys %rates;
    for my $row (values %rates) {
        next unless $row->[0] eq $ip;
        return 0 if $row->[2] >= 10;
        $row->[2]++;
        write_rows("$BASE/.attempts", \%rates); return 1;
    }
    return 0 if keys(%rates) >= 4096;
    $rates{next_key(\%rates)}=[$ip,$now,1];
    write_rows("$BASE/.attempts", \%rates); return 1;
}

# IPFire's GUI list is code:native-name:English-name. Keep its order and labels.
sub gui_languages {
    my ($file) = @_;
    $file //= '/var/ipfire/langs/list';
    my @languages;
    my %seen;
    if (open(my $fh, '<:raw', $file)) {
        while (<$fh>) {
            s/[\r\n]+\z//;
            next if /^\s*(?:#|$)/;
            my ($code, $native, $english) = split /:/, $_, 3;
            next unless defined($code) && $code =~ /^[a-z]{2}(?:[-_][A-Za-z0-9]+)*\z/ && !$seen{$code}++;
            my $name = length($native // '') ? $native : (length($english // '') ? $english : $code);
            push @languages, [$code, $name];
        }
        close $fh;
    }
    # A missing list must not leave the management form unusable.
    return @languages if @languages;
    return map { [$_->[0], Encode::encode('UTF-8', $_->[1])] } (
        ['de','Deutsch'], ['en','English'], ['es','Español'], ['fr','Français'],
        ['it','Italiano'], ['nl','Nederlands'], ['pl','Polski'], ['ru','Русский'],
        ['tr','Türkçe'], ['tw','繁體中文'], ['zh','简体中文']);
}
# Coupon choices come from installed dictionaries, independent of GUI languages.
sub coupon_languages {
    my %names=map {$_->[0]=>$_->[1]} gui_languages();
    $names{br}=Encode::encode('UTF-8','Português do Brasil');
    $names{pt}=Encode::encode('UTF-8','Português');
    my %codes;
    if (opendir(my $dir,"$BASE/languages")) {
        for my $file (readdir($dir)) {
            next unless $file =~ /^captive\.([a-z]{2}(?:[-_][A-Za-z0-9]+)*)\.txt\z/ && -r "$BASE/languages/$file";
            my $code=$1; $codes{$code}=1;
            if (open(my $fh,'<:raw',"$BASE/languages/$file")) {
                while (<$fh>) {
                    s/[\r\n]+\z//;
                    if (/^language_name=(.{1,200})\z/) {$names{$code}=$1;last;}
                }
                close $fh;
            }
        }
        closedir $dir;
    }
    return ['en','English'] unless %codes;
    return map {[$_, $names{$_}//$_]} sort keys %codes;
}
sub coupon_language {
    my ($value, $gui, $languages) = @_;
    my %available = map { $_->[0] => 1 } @$languages;
    $value = $gui if !defined($value) || $value eq '' || $value eq 'auto';
    return defined($value) && $available{$value} ? $value : 'en';
}

sub coupon_words {
    my ($value,$gui)=@_;
    my @available=coupon_languages();
    my $language=coupon_language($value||'en',$gui,\@available);
    my %words;
    for my $code ('en',$language eq 'en'?():$language) {
        open(my $fh,'<:raw',"$BASE/languages/captive.$code.txt") or next;
        while (<$fh>) {
            s/[\r\n]+\z//;next if /^\s*(?:#|$)/;
            my ($key,$text)=split(/=/,$_,2);
            $words{$key}=$text if defined($text);
        }
        close $fh;
    }
    return ($language,\%words);
}
sub coupon_duration {
    my ($seconds,$words)=@_;
    my %keys=(0=>'unlimited',3600=>'1_hour',14400=>'4_hours',28800=>'8_hours',43200=>'12_hours',86400=>'24_hours',604800=>'1_week',1209600=>'2_weeks',2592000=>'1_month',31536000=>'1_year');
    return $words->{$keys{$seconds}||'unlimited'} // $seconds;
}
sub wireless_reload { return system('/usr/local/bin/wirelessctrl') == 0; }
sub reload {
    # Only IPFire's existing setuid controller manages firewall/expiry rules.
    return system('/usr/local/bin/captivectrl') == 0;
}
1;
