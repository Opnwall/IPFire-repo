#!/usr/bin/perl
use strict;
use warnings;

my ($target, $snippet) = @ARGV;
die "Usage: $0 TARGET SNIPPET\n" unless ($target && $snippet);

open(my $target_fh, '<', $target) or die "Cannot read $target: $!\n";
my @lines = <$target_fh>;
close($target_fh);

open(my $snippet_fh, '<', $snippet) or die "Cannot read $snippet: $!\n";
my @entries = <$snippet_fh>;
close($snippet_fh);

my @keys = map { /^'([^']+)'\s*=>/ ? $1 : () } @entries;
my %new_key = map { $_ => 1 } @keys;
@lines = grep {
	my ($key) = /^'([^']+)'\s*=>/;
	!defined($key) || !$new_key{$key};
} @lines;

my $terminator = -1;
for my $i (0 .. $#lines) {
	$terminator = $i if ($lines[$i] =~ /^\s*\);\s*$/);
}
die "No standalone language hash terminator found in $target\n" if ($terminator < 0);

splice(@lines, $terminator, 0, @entries);
my $tmp = "$target.tmp.$$";
open(my $out, '>', $tmp) or die "Cannot write $tmp: $!\n";
print $out @lines;
close($out) or die "Cannot close $tmp: $!\n";

my @stat = stat($target);
chmod($stat[2] & 07777, $tmp);
chown($stat[4], $stat[5], $tmp);
rename($tmp, $target) or die "Cannot replace $target: $!\n";
