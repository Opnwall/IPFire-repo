#!/usr/bin/perl
# Read-only anonymous HTTPS coupon export. GPL-3.0-or-later.
use strict;
use warnings;
require '/var/ipfire/general-functions.pl';
require '/var/ipfire/captive-lib.pl';
require '/var/ipfire/captive-pdf.pl';
Captive::fail('403 Forbidden','https_required') unless ($ENV{HTTPS}//'') eq 'on';
unless (($ENV{REQUEST_METHOD}//'GET') =~ /^(GET|HEAD)\z/) {
    # Drain a small rejected request body so Apache can finish the HTTP response.
    my $length=$ENV{CONTENT_LENGTH}//'0';
    if ($length =~ /^\d{1,8}\z/ && $length<=1048576) {
        while ($length>0) {
            my $got=read(STDIN,my $ignored,$length>8192?8192:$length);
            last unless defined($got) && $got>0;
            $length-=$got;
        }
    }
    my $message=Captive::tr('invalid_request')."\n";
    binmode(STDOUT,':raw');
    print "Status: 405 Method Not Allowed\r\nAllow: GET, HEAD\r\nContent-Type: text/plain; charset=UTF-8\r\nCache-Control: no-store\r\nContent-Length: ".length($message)."\r\n\r\n$message";
    exit;
}
my $lock=Captive::lock();
my (%stored,%main,%rows);
General::readhash('/var/ipfire/captive/settings',\%stored);
General::readhash('/var/ipfire/main/settings',\%main);
Captive::read_rows('/var/ipfire/captive/coupons',\%rows);
close $lock;
my %settings=map {lc($_)=>$stored{$_}} keys %stored;
my ($language,$words)=Captive::coupon_words($settings{translate}||$settings{traslate}||'en',$main{LANGUAGE});
my $pdf=CaptivePDF::generate(coupons=>\%rows,title=>$words->{pdf_title}||'IPFire Captive Portal',company=>$settings{company}//'',ssid=>$settings{ssid}//'',
    labels=>{company=>$words->{company_prefix},ssid=>$words->{ssid_prefix},validity=>$words->{valid_until},remark=>$words->{note_prefix},empty=>$words->{no_coupons}},
    duration=>sub {Captive::coupon_duration($_[0],$words)},
);
binmode(STDOUT,':raw');
print "Content-Type: application/pdf\r\nCache-Control: no-store, private\r\nContent-Disposition: attachment; filename=captive-portal-coupons.pdf\r\nContent-Length: ".length($pdf)."\r\n\r\n";
print $pdf unless ($ENV{REQUEST_METHOD}//'') eq 'HEAD';
