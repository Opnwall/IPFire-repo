#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
my $library = shift // "$FindBin::Bin/../src/captive-enhanced/src/var/ipfire/captive-lib.pl";
require $library;
my $count = 0;
for my $url (undef, '', 'http://neverssl.com/', 'https://example.com/',
    'http://edge-http.microsoft.com/captiveportal/generate_204',
    'http://www.msftconnecttest.com/connecttest.txt',
    'http://www.msftncsi.com/ncsi.txt', '//evil.example/',
    "https://example.com/\r\nLocation: https://evil.example/") {
    die "Unexpected redirect in case " . ($count + 1) . "\n"
        unless Captive::post_auth_url($url) eq 'https://www.bing.com/';
    print 'ok ' . ++$count . " - fixed HTTPS destination\n";
}
print "1..$count\n";
