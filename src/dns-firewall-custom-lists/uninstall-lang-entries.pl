#!/usr/bin/perl
use strict;
use warnings;

my ($target) = @ARGV;
die "Usage: $0 TARGET\n" unless $target;

my %remove = map { $_ => 1 } qw(
	dnsbl_acl_updated
	dnsbl_custom_list_add
	dnsbl_custom_list_added
	dnsbl_custom_list_delete
	dnsbl_custom_list_delete_confirm
	dnsbl_custom_list_delete_not_found
	dnsbl_custom_list_deleted
	dnsbl_custom_list_edit_not_found
	dnsbl_custom_list_help
	dnsbl_custom_list_interval_invalid
	dnsbl_custom_list_license
	dnsbl_custom_list_name
	dnsbl_custom_list_name_required
	dnsbl_custom_list_primary_required
	dnsbl_custom_list_updated
	dnsbl_custom_list_update_interval
	dnsbl_custom_list_url
	dnsbl_custom_list_url_exists
	dnsbl_custom_list_url_invalid
	dnsbl_custom_list_zone_exists
	dnsbl_custom_list_zone_invalid
	dnsbl_custom_rpz_list
	dnsbl_list_information
	dnsbl_list_primary
	dnsbl_list_zone
	dnsbl_official_list_readonly
	information
);

open(my $in, '<', $target) or die "Cannot read $target: $!\n";
my @lines = <$in>;
close($in);

@lines = grep {
	my ($key) = /^'([^']+)'\s*=>/;
	if (defined $key) {
		(my $normalized = $key) =~ tr/ /_/;
		!$remove{$normalized};
	} else {
		1;
	}
} @lines;

my $tmp = "$target.tmp.$$";
open(my $out, '>', $tmp) or die "Cannot write $tmp: $!\n";
print $out @lines;
close($out) or die "Cannot close $tmp: $!\n";

my @stat = stat($target);
chmod($stat[2] & 07777, $tmp);
chown($stat[4], $stat[5], $tmp);
rename($tmp, $target) or die "Cannot replace $target: $!\n";
