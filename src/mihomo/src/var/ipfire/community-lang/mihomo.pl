# Core 206 gettext compatibility for legacy community addon strings.
# GPL-2.0-or-later. Core fallback dictionaries: IPFire v2.29-core204.
package Lang;
use strict;
use warnings;
our (%tr, $language);
my $directory = __FILE__; $directory =~ s/\.pl$//;
my $code = lc($language || 'en'); $code =~ tr/-/_/;
$code = 'tw' if $code =~ /^(?:tw|zh_(?:tw|hk|mo|hant)(?:_|$))/;
$code = 'zh' if $code =~ /^(?:zh|cn|zh_(?:cn|sg|hans)(?:_|$))$/;
my (%english, %localized);
{ local %tr; do "$directory/core.en.pl" or die "Missing English community dictionary: $@ $!"; %english = %tr; }
if ($code eq 'zh' || $code eq 'tw') {
    local %tr; do "$directory/core.$code.pl" or die "Missing Chinese community dictionary: $@ $!";
    %localized = %tr;
}
# Legacy aliases no longer provided by the Core 206 dictionaries.
my %aliases = (
    'Captive clients' => ['Clients', '客户端', '用戶端'],
    'guardian invalid address or subnet' => ['Invalid host address or subnet.', '主机地址或子网无效。', '主機位址或子網無效。'],
    'information' => ['Information', '信息', '資訊'],
    'settings saved' => ['Settings saved', '设置已保存', '設定已儲存'],
);
for my $key (keys %aliases) {
    $english{$key} = $aliases{$key}[0];
    $localized{$key} = $aliases{$key}[$code eq 'tw' ? 2 : 1] if $code eq 'zh' || $code eq 'tw';
}
for my $key (keys %english) {
    next if defined($tr{$key}) && length($tr{$key});
    my $english = $english{$key};
    my $value = defined(&main::_) ? main::_($english) : $english;
    $value = $localized{$key} if $value eq $english && defined($localized{$key});
    $tr{$key} = $value;
}
# Load native addon dictionaries in English first, then the selected language.
for my $name (qw()) {
    for my $locale ('en', $code eq 'en' ? () : $code) {
        next unless $locale =~ /^[a-z]{2}(?:_[a-z0-9]+)*$/;
        my $file = "/var/ipfire/addon-lang/$name.$locale.pl";
        # During isolated checks resolve resources next to the staged loader.
        my $staged = $directory; $staged =~ s{/community-lang/[^/]+$}{/addon-lang};
        $file = "$staged/$name.$locale.pl" if -f "$staged/$name.$locale.pl";
        do $file if -f $file;
    }
}
1;
