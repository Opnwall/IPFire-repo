#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A Linux Firewall                                               #
# Copyright (C) 2007-2024  IPFire Team                                        #
#                                                                             #
# Firewall Backup Addon                                                       #
#                                                                             #
# Each backup is stored as a single compressed package (.tar.gz) containing   #
# all firewall rules and host/service/network/location group definitions,     #
# plus a metadata file (date + comment). Backups can be created, restored,    #
# deleted, exported (download) and imported (upload).                         #
#                                                                             #
###############################################################################

use strict;
use warnings;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use File::Copy;
use File::Path qw(make_path remove_tree);
use POSIX qw(strftime);

# Limits for uploads (import). Set before CGI->new.
$CGI::POST_MAX      = 50 * 1024 * 1024;   # 50 MB max upload
$CGI::DISABLE_UPLOADS = 0;

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";
require "/usr/lib/firewall/firewall-lib.pl";

# Load addon translations. IPFire uses "zh" for Simplified Chinese and "tw"
# for Traditional Chinese; accept common aliases such as "cn" by mapping them
# to the canonical addon language files.
eval {
    my $language = defined $Lang::language ? $Lang::language : '';
    my $normalized = lc($language);
    $normalized =~ s/-/_/g;

    my @languages = ($language);
    if ($normalized eq 'cn' || $normalized eq 'zh_cn' || $normalized eq 'zh_hans' || $normalized eq 'zh_sg') {
        push @languages, 'zh';
    } elsif ($normalized eq 'tw' || $normalized eq 'zh_tw' || $normalized eq 'zh_hant' || $normalized eq 'zh_hk' || $normalized eq 'zh_mo') {
        push @languages, 'tw';
    }
    push @languages, 'en';

    my %seen;
    foreach my $lang (@languages) {
        next unless defined $lang && $lang ne '';
        next unless $lang =~ /^[A-Za-z0-9_-]+$/;
        next if $seen{$lang}++;

        my $file = "${General::swroot}/addon-lang/firewall_backup.$lang.pl";
        if (-f $file) {
            require $file;
            last;
        }
    }
};

# Path configuration
my $backup_base_dir     = "/var/ipfire/firewall_backup";
my $firewall_config_dir = "/var/ipfire/firewall";
my $fwhosts_config_dir  = "/var/ipfire/fwhosts";

# Files to back up
my @firewall_files = qw(config input locationblock outgoing settings);
my @fwgroups_files = qw(customgroups customhosts customlocationgrp customnetworks
                        customservicegrp customservices customservices.default icmp-types);

# CGI variables
my $cgi = CGI->new;
my %cgiparams = ();
foreach my $param ($cgi->param()) {
    $cgiparams{$param} = scalar $cgi->param($param);
}

# Message variables
my $errormessage   = '';
my $successmessage = '';

# Ensure base directory exists
unless (-d $backup_base_dir) {
    eval { make_path($backup_base_dir, { mode => 0755 }); };
    if ($@) {
        $errormessage = "Error creating base directory: $@";
    }
}

# One-time migration of legacy (uncompressed directory) backups to .tar.gz
migrate_legacy_backups();

# Action dispatch
my $action = defined $cgiparams{'ACTION'} ? $cgiparams{'ACTION'} : '';

if ($action eq 'download_backup') {
    # Streams the archive and exits on success; on failure falls through with an error.
    exit if download_backup($cgiparams{'backup_name'});
} elsif ($action eq 'create_backup') {
    create_backup();
} elsif ($action eq 'restore_backup') {
    restore_backup($cgiparams{'backup_name'});
} elsif ($action eq 'delete_backup') {
    delete_backup($cgiparams{'backup_name'});
} elsif ($action eq 'import_backup') {
    import_backup();
}

# HTML headers
&Header::showhttpheaders();
&Header::openpage(get_text('firewall backup title', 'Firewall Backup'), 1, '');
&Header::openbigbox('100%', 'left', '', $errormessage);

# Messages (styled banners)
if ($errormessage) {
    print "<div class='fwbk-alert fwbk-alert-err'>$errormessage</div>\n";
}

if ($successmessage) {
    print "<div class='fwbk-alert fwbk-alert-ok'>$successmessage</div>\n";
}

# CSS
print <<'EOF';
<style>
.fwbk { font-size: 12px; color: #24292f; }
.fwbk-stats { display: flex; gap: 10px; flex-wrap: wrap; margin: 0 0 12px; }
.fwbk-stat { flex: 1 1 130px; background: #f3f5f7; border: 1px solid #d9dee3;
             border-radius: 6px; padding: 9px 12px; text-align: center; }
.fwbk-stat .num { font-size: 22px; font-weight: bold; color: #1f6feb; line-height: 1.15; }
.fwbk-stat .lbl { font-size: 10px; color: #57606a; text-transform: uppercase;
                  letter-spacing: .04em; margin-top: 2px; }
.fwbk-cols { display: flex; gap: 14px; flex-wrap: wrap; }
.fwbk-card { flex: 1 1 280px; background: #fafbfc; border: 1px solid #e2e6ea;
             border-radius: 6px; padding: 11px 13px; }
.fwbk-card h3 { margin: 0 0 9px; font-size: 13px; color: #24292f; }
.fwbk-card input[type=text], .fwbk-card input[type=file] { width: 100%; box-sizing: border-box;
             padding: 6px 8px; border: 1px solid #c7ced4; border-radius: 4px;
             margin-bottom: 9px; font-size: 12px; background: #fff; }
.fwbk-hint { color: #6a737d; font-size: 11px; margin: 0 0 9px; line-height: 1.4; }
input.fwbk-btn { display: inline-block; padding: 5px 13px; border: 0; border-radius: 4px;
             font-size: 12px; font-weight: bold; color: #fff !important; cursor: pointer; }
input.fwbk-btn-primary { background: #1f6feb; }
input.fwbk-btn-restore { background: #1a7f37; }
input.fwbk-btn-export  { background: #57606a; }
input.fwbk-btn-delete  { background: #cf222e; }
input.fwbk-btn:hover { filter: brightness(1.1); }
table.fwbk-table { width: 100%; border-collapse: collapse; font-size: 12px; }
table.fwbk-table th, table.fwbk-table td { padding: 6px 9px; border-bottom: 1px solid #e6e9ec;
             text-align: left; vertical-align: middle; }
table.fwbk-table th { background: #eef1f4; font-weight: bold; border-bottom: 2px solid #d4dade;
             white-space: nowrap; }
table.fwbk-table tr:nth-child(even) td { background: #fafbfc; }
table.fwbk-table tr:hover td { background: #f0f6ff; }
.fwbk-name { font-family: monospace; font-size: 11px; }
.fwbk-comment { color: #3a3f45; }
.fwbk-actions2 { white-space: nowrap; text-align: right; }
.fwbk-actions2 form { display: inline; margin: 0 0 0 4px; }
.fwbk-empty { color: #6a737d; font-style: italic; }
.fwbk-alert { padding: 9px 12px; border-radius: 5px; font-weight: bold; font-size: 12px;
             margin: 0 0 12px; border: 1px solid; }
.fwbk-alert-ok  { background: #e7f6ec; color: #1a7f37; border-color: #aadfc0; }
.fwbk-alert-err { background: #fde8e9; color: #b62324; border-color: #f3b6b9; }
</style>
EOF

# Render UI
show_main_interface();

&Header::closebigbox();
&Header::closepage();

###############################################################################
# Helpers
###############################################################################

# Translated text with fallback
sub get_text {
    my ($key, $default) = @_;
    return (defined $Lang::tr{$key} && $Lang::tr{$key} ne '') ? $Lang::tr{$key} : $default;
}

# Escape text for safe HTML output
sub escape_html {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

# Reject anything that is not a plain backup identifier (no path traversal)
sub sanitize_name {
    my ($name) = @_;
    return '' unless defined $name;
    $name =~ s/\.tar\.gz$//;            # tolerate full filename
    return '' if $name =~ /[\/\\]/;     # no path separators
    return '' if $name =~ /\.\./;       # no parent references
    return '' unless $name =~ /^[A-Za-z0-9_.\-]+$/;
    return $name;
}

# Collapse a user comment into a single safe line
sub sanitize_comment {
    my ($c) = @_;
    return '' unless defined $c;
    $c =~ s/[\r\n]+/ /g;
    $c =~ s/^\s+|\s+$//g;
    $c = substr($c, 0, 255);
    return $c;
}

# Absolute path of a backup archive given its name
sub archive_path {
    my ($name) = @_;
    return "$backup_base_dir/$name.tar.gz";
}

# Human readable size
sub format_size {
    my ($bytes) = @_;
    return 'N/A' unless defined $bytes;
    my @u = ('B', 'KB', 'MB', 'GB');
    my $i = 0;
    my $s = $bytes;
    while ($s >= 1024 && $i < $#u) { $s /= 1024; $i++; }
    return sprintf(($i == 0 ? "%d %s" : "%.1f %s"), $s, $u[$i]);
}

# Byte-for-byte comparison of two files
sub files_differ {
    my ($a, $b) = @_;
    return 1 if (-s $a // -1) != (-s $b // -1);
    local $/;
    open(my $fa, '<', $a) or return 1; binmode $fa; my $da = <$fa>; close $fa;
    open(my $fb, '<', $b) or return 1; binmode $fb; my $db = <$fb>; close $fb;
    return ((defined $da ? $da : '') ne (defined $db ? $db : '')) ? 1 : 0;
}

# True if a file begins with the gzip magic bytes
sub is_gzip {
    my ($f) = @_;
    open(my $fh, '<', $f) or return 0;
    binmode $fh;
    my $m = '';
    read($fh, $m, 2);
    close $fh;
    return (length($m) == 2 && ord(substr($m, 0, 1)) == 0x1f && ord(substr($m, 1, 1)) == 0x8b) ? 1 : 0;
}

# Locate the directory that actually holds the backup contents inside an
# extracted tree (handles both canonical "./firewall" layouts and archives
# wrapped in a single top-level directory).
sub find_content_root {
    my ($base) = @_;
    return $base if -e "$base/backup_info.txt" || -d "$base/firewall" || -d "$base/fwhosts";
    opendir(my $dh, $base) or return undef;
    my @subs = grep { !/^\./ && -d "$base/$_" } readdir($dh);
    closedir($dh);
    foreach my $s (@subs) {
        my $p = "$base/$s";
        return $p if -e "$p/backup_info.txt" || -d "$p/firewall" || -d "$p/fwhosts";
    }
    return undef;
}

# Copy the current firewall configuration into a staging directory and write
# its metadata file. Returns (1) on success or (0, @errors) on failure.
sub populate_staging {
    my ($staging, $comment, $backup_name) = @_;
    my @errors;

    eval {
        make_path("$staging/firewall", { mode => 0700 });
        make_path("$staging/fwhosts",  { mode => 0700 });
    };
    return (0, "mkdir: $@") if $@;

    foreach my $file (@firewall_files) {
        my $src = "$firewall_config_dir/$file";
        next unless -f $src;
        unless (copy($src, "$staging/firewall/$file")) {
            push @errors, get_text('error copying', 'Error copying') . " $file: $!";
        }
    }
    foreach my $file (@fwgroups_files) {
        my $src = "$fwhosts_config_dir/$file";
        next unless -f $src;
        unless (copy($src, "$staging/fwhosts/$file")) {
            push @errors, get_text('error copying', 'Error copying') . " $file: $!";
        }
    }

    if (open(my $fh, '>', "$staging/backup_info.txt")) {
        print $fh "Backup Name: $backup_name\n";
        print $fh "Timestamp: " . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n";
        print $fh "Comment: $comment\n";
        close($fh);
    } else {
        push @errors, "backup_info.txt: $!";
    }

    return (scalar(@errors) ? 0 : 1, @errors);
}

# Pack the contents of a directory into a canonical .tar.gz (members are ./...)
sub pack_staging {
    my ($contents_dir, $archive) = @_;
    my $rc = system("tar", "-czf", $archive, "-C", $contents_dir, ".");
    return ($rc == 0 && -f $archive) ? 1 : 0;
}

# Create a compressed snapshot of the CURRENT configuration. Returns 1/0.
sub create_snapshot_backup {
    my ($name, $comment) = @_;
    my $staging = "/tmp/fwbackup_stage_" . $$ . "_" . time() . "_snap";
    my ($ok)  = populate_staging($staging, $comment, $name);
    my $packed = $ok ? pack_staging($staging, archive_path($name)) : 0;
    remove_tree($staging) if -d $staging;
    return $packed;
}

###############################################################################
# Actions
###############################################################################

# Create a new backup of the current configuration
sub create_backup {
    my $comment   = sanitize_comment($cgiparams{'backup_comment'});
    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
    my $backup_name = "firewall_backup_$timestamp";
    my $archive   = archive_path($backup_name);

    if (-e $archive) {
        $errormessage = "[ERROR] " . get_text('backup already exists', 'A backup with this name already exists');
        return;
    }

    my $staging = "/tmp/fwbackup_stage_" . $$ . "_" . time();
    my ($ok, @errors) = populate_staging($staging, $comment, $backup_name);

    if (!$ok) {
        remove_tree($staging) if -d $staging;
        $errormessage = "[ERROR] " . get_text('errors during backup', 'Errors during backup') . ":<br>"
                      . join("<br>", map { escape_html($_) } @errors);
        return;
    }

    if (pack_staging($staging, $archive)) {
        $successmessage = "[OK] " . get_text('backup created successfully', 'Backup created successfully')
                        . ": " . escape_html($backup_name);
    } else {
        $errormessage = "[ERROR] " . get_text('failed to create archive', 'Failed to create compressed archive');
    }

    remove_tree($staging) if -d $staging;
}

# Restore a backup over the current configuration
sub restore_backup {
    my ($name) = @_;
    $name = sanitize_name($name);
    unless ($name) {
        $errormessage = "[ERROR] " . get_text('invalid backup name', 'Invalid backup name');
        return;
    }

    my $archive = archive_path($name);
    unless (-f $archive) {
        $errormessage = "[ERROR] " . get_text('backup not found', 'Backup not found') . ": " . escape_html($name);
        return;
    }

    # Extract to an isolated temporary directory
    my $tmp = "/tmp/fwbackup_restore_" . $$ . "_" . time();
    eval { make_path($tmp, { mode => 0700 }); };
    if ($@) {
        $errormessage = "[ERROR] " . get_text('error extracting backup', 'Error extracting backup') . ": $@";
        return;
    }

    if (system("tar", "-xzf", $archive, "-C", $tmp) != 0) {
        remove_tree($tmp);
        $errormessage = "[ERROR] " . get_text('error extracting backup', 'Error extracting backup');
        return;
    }

    my $root = find_content_root($tmp);
    unless ($root) {
        remove_tree($tmp);
        $errormessage = "[ERROR] " . get_text('invalid backup file', 'The file is not a valid firewall backup');
        return;
    }

    # If the backup matches the running configuration, do nothing
    unless (backup_differs_from_current($root)) {
        remove_tree($tmp);
        $successmessage = "[INFO] " . get_text('backup identical to current',
            'The selected backup is identical to the current configuration. No changes made.');
        return;
    }

    # Safety snapshot of the current configuration so the restore can be undone
    my $auto_name = "current_before_restore_" . strftime("%Y%m%d_%H%M%S", localtime);
    my $auto_ok   = create_snapshot_backup($auto_name,
                        get_text('automatic backup comment', 'Automatic backup before restoration'));

    my $success = 1;
    my @errors;

    foreach my $file (@firewall_files) {
        my $src = "$root/firewall/$file";
        next unless -f $src;
        unless (copy($src, "$firewall_config_dir/$file")) {
            push @errors, get_text('error restoring', 'Error restoring') . " $file: $!";
            $success = 0;
        }
    }
    foreach my $file (@fwgroups_files) {
        my $src = "$root/fwhosts/$file";
        next unless -f $src;
        unless (copy($src, "$fwhosts_config_dir/$file")) {
            push @errors, get_text('error restoring', 'Error restoring') . " $file: $!";
            $success = 0;
        }
    }

    remove_tree($tmp);

    if ($success) {
        # Flag the firewall configuration as changed so the WUI shows "Apply"
        if (General->can('firewall_config_changed')) {
            General::firewall_config_changed();
        }

        $successmessage  = "[OK] " . get_text('backup restored successfully', 'Backup restored successfully') . "<br>";
        if ($auto_ok) {
            $successmessage .= "[INFO] " . get_text('current config saved as', 'Current config saved as')
                             . ": " . escape_html($auto_name) . "<br>";
        }
        $successmessage .= "[INFO] " . get_text('firewall changes pending',
            'Firewall configuration changed. Use the Apply button to activate changes.');
    } else {
        $errormessage = "[ERROR] " . get_text('errors during restoration', 'Errors during restoration') . ":<br>"
                      . join("<br>", map { escape_html($_) } @errors);
    }
}

# Compare an extracted backup against the live configuration
sub backup_differs_from_current {
    my ($root) = @_;

    foreach my $file (@firewall_files) {
        my $cur = "$firewall_config_dir/$file";
        my $bak = "$root/firewall/$file";
        return 1 if (-f $cur ? 1 : 0) != (-f $bak ? 1 : 0);
        return 1 if (-f $cur && -f $bak && files_differ($cur, $bak));
    }
    foreach my $file (@fwgroups_files) {
        my $cur = "$fwhosts_config_dir/$file";
        my $bak = "$root/fwhosts/$file";
        return 1 if (-f $cur ? 1 : 0) != (-f $bak ? 1 : 0);
        return 1 if (-f $cur && -f $bak && files_differ($cur, $bak));
    }
    return 0;
}

# Delete a backup archive
sub delete_backup {
    my ($name) = @_;
    $name = sanitize_name($name);
    unless ($name) {
        $errormessage = "[ERROR] " . get_text('invalid backup name', 'Invalid backup name');
        return;
    }

    my $archive = archive_path($name);
    if (-f $archive) {
        if (unlink($archive)) {
            $successmessage = "[OK] " . get_text('backup deleted successfully', 'Backup deleted successfully')
                            . ": " . escape_html($name);
        } else {
            $errormessage = "[ERROR] " . get_text('error deleting backup', 'Error deleting backup') . ": $!";
        }
    } else {
        $errormessage = "[ERROR] " . get_text('backup not found', 'Backup not found') . ": " . escape_html($name);
    }
}

# Export: stream a backup archive to the browser. Returns 1 if streamed.
sub download_backup {
    my ($name) = @_;
    $name = sanitize_name($name);
    unless ($name) {
        $errormessage = "[ERROR] " . get_text('invalid backup name', 'Invalid backup name');
        return 0;
    }

    my $archive = archive_path($name);
    unless (-f $archive) {
        $errormessage = "[ERROR] " . get_text('backup not found', 'Backup not found') . ": " . escape_html($name);
        return 0;
    }

    print "Content-Type: application/octet-stream\r\n";
    print "Content-Disposition: attachment; filename=\"$name.tar.gz\"\r\n";
    print "Content-Length: " . (-s $archive) . "\r\n\r\n";

    if (open(my $fh, '<', $archive)) {
        binmode $fh;
        binmode STDOUT;
        local $/ = \65536;
        print while <$fh>;
        close $fh;
        return 1;
    }

    $errormessage = "[ERROR] " . get_text('failed to read backup', 'Failed to read backup file');
    return 0;
}

# Import: accept an uploaded .tar.gz, validate it and store it as a backup
sub import_backup {
    my $upload_fh = $cgi->upload('import_file');
    unless (defined $upload_fh) {
        $errormessage = "[ERROR] " . get_text('no file selected', 'No file selected for import');
        return;
    }

    # Save the upload to a temporary file
    my $up = "/tmp/fwimport_" . $$ . "_" . time() . ".tar.gz";
    unless (open(my $out, '>', $up)) {
        $errormessage = "[ERROR] " . get_text('import error', 'Error importing backup') . ": $!";
        return;
    } else {
        binmode $out;
        binmode $upload_fh;
        my $buf;
        while (read($upload_fh, $buf, 65536)) { print $out $buf; }
        close $out;
    }

    # Must look like a gzip file
    unless (is_gzip($up)) {
        unlink $up;
        $errormessage = "[ERROR] " . get_text('invalid backup file', 'The file is not a valid firewall backup');
        return;
    }

    # Inspect archive members and reject anything unsafe (path traversal / absolute paths)
    my @members;
    if (open(my $tp, '-|', 'tar', '-tzf', $up)) {
        @members = <$tp>;
        close $tp;
    }
    unless (@members) {
        unlink $up;
        $errormessage = "[ERROR] " . get_text('invalid backup file', 'The file is not a valid firewall backup');
        return;
    }
    foreach my $m (@members) {
        chomp $m;
        if ($m =~ m{(^|/)\.\.(/|$)} || $m =~ m{^/} || $m =~ m{^[A-Za-z]:}) {
            unlink $up;
            $errormessage = "[ERROR] " . get_text('unsafe archive', 'The archive contains unsafe paths and was rejected');
            return;
        }
    }

    # Extract to an isolated staging directory
    my $stage = "/tmp/fwimport_stage_" . $$ . "_" . time();
    eval { make_path($stage, { mode => 0700 }); };
    if ($@) {
        unlink $up;
        $errormessage = "[ERROR] " . get_text('import error', 'Error importing backup') . ": $@";
        return;
    }

    my $rc = system("tar", "-xzf", $up, "-C", $stage);
    unlink $up;
    if ($rc != 0) {
        remove_tree($stage);
        $errormessage = "[ERROR] " . get_text('import error', 'Error importing backup');
        return;
    }

    my $root = find_content_root($stage);
    unless ($root) {
        remove_tree($stage);
        $errormessage = "[ERROR] " . get_text('invalid backup file', 'The file is not a valid firewall backup');
        return;
    }

    # Must contain at least one recognised firewall file or a metadata file
    my $valid = (-e "$root/backup_info.txt") ? 1 : 0;
    unless ($valid) {
        foreach my $f (@firewall_files) { if (-f "$root/firewall/$f") { $valid = 1; last; } }
    }
    unless ($valid) {
        foreach my $f (@fwgroups_files) { if (-f "$root/fwhosts/$f") { $valid = 1; last; } }
    }
    unless ($valid) {
        remove_tree($stage);
        $errormessage = "[ERROR] " . get_text('invalid backup file', 'The file is not a valid firewall backup');
        return;
    }

    # Ensure a metadata file exists (generate one for archives without it)
    unless (-e "$root/backup_info.txt") {
        if (open(my $fh, '>', "$root/backup_info.txt")) {
            print $fh "Backup Name: imported\n";
            print $fh "Timestamp: " . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n";
            print $fh "Comment: " . get_text('imported comment', 'Imported backup') . "\n";
            close $fh;
        }
    }

    # Pick a unique target name
    my $base_name = "firewall_backup_imported_" . strftime("%Y%m%d_%H%M%S", localtime);
    my $target = $base_name;
    my $i = 1;
    while (-e archive_path($target)) { $target = $base_name . "_$i"; $i++; }

    # Repackage in canonical form
    if (pack_staging($root, archive_path($target))) {
        $successmessage = "[OK] " . get_text('backup imported successfully', 'Backup imported successfully')
                        . ": " . escape_html($target);
    } else {
        $errormessage = "[ERROR] " . get_text('failed to store backup', 'Failed to store the imported backup');
    }

    remove_tree($stage);
}

# Convert any legacy uncompressed (directory) backups into .tar.gz archives
sub migrate_legacy_backups {
    return unless -d $backup_base_dir;
    opendir(my $dh, $backup_base_dir) or return;
    my @dirs = grep { !/^\./ && -d "$backup_base_dir/$_" } readdir($dh);
    closedir($dh);

    foreach my $d (@dirs) {
        my $path = "$backup_base_dir/$d";
        next unless (-e "$path/backup_info.txt" || -d "$path/firewall" || -d "$path/fwhosts");
        my $archive = "$backup_base_dir/$d.tar.gz";
        next if -e $archive;
        if (pack_staging($path, $archive)) {
            remove_tree($path);
        }
    }
}

# Build the list of available backups (most recent first)
sub get_backup_list {
    my @backups;
    return @backups unless -d $backup_base_dir;

    opendir(my $dh, $backup_base_dir) or return @backups;
    my @files = grep { /\.tar\.gz$/ && -f "$backup_base_dir/$_" } readdir($dh);
    closedir($dh);

    foreach my $file (@files) {
        (my $name = $file) =~ s/\.tar\.gz$//;
        my $archive = "$backup_base_dir/$file";

        my %info = (
            name      => $name,
            timestamp => 'N/A',
            comment   => get_text('no comment', 'No comment'),
        );

        # Read metadata from inside the archive
        my $meta = '';
        if (open(my $tp, '-|', 'tar', '-xzO', '-f', $archive, '--wildcards', '*backup_info.txt')) {
            local $/;
            $meta = <$tp>;
            close $tp;
        }
        if (defined $meta && $meta ne '') {
            foreach my $line (split /\n/, $meta) {
                if ($line =~ /^Timestamp:\s*(.+)$/) {
                    $info{timestamp} = $1;
                } elsif ($line =~ /^Comment:\s*(.*)$/) {
                    $info{comment} = ($1 ne '') ? $1 : get_text('no comment', 'No comment');
                }
            }
        }

        my $bytes = -s $archive;
        $info{bytes} = $bytes;
        $info{size}  = format_size($bytes);
        $info{mtime} = (stat($archive))[9] || 0;

        push @backups, \%info;
    }

    return sort { $b->{mtime} <=> $a->{mtime} } @backups;
}

###############################################################################
# User interface
###############################################################################

sub show_main_interface {
    my @backups = get_backup_list();
    my $backup_count = scalar @backups;

    my $total_bytes = 0;
    $total_bytes += ($_->{bytes} || 0) for @backups;
    my $last_backup = $backup_count ? $backups[0]{timestamp} : get_text('never', 'Never');

    my $script = $ENV{'SCRIPT_NAME'} || '';

    # ===== Manager: statistics + create + import (single compact box) =====
    &Header::openbox('100%', 'left', get_text('firewall backup manager', 'Firewall Backup Manager'));
    print "<div class='fwbk'>\n";

    # Statistic cards
    print "<div class='fwbk-stats'>\n";
    print "  <div class='fwbk-stat'><div class='num'>$backup_count</div>"
        . "<div class='lbl'>" . get_text('total backups', 'Total Backups') . "</div></div>\n";
    print "  <div class='fwbk-stat'><div class='num'>" . format_size($total_bytes) . "</div>"
        . "<div class='lbl'>" . get_text('total size', 'Total Size') . "</div></div>\n";
    print "  <div class='fwbk-stat'><div class='num' style='font-size:13px'>" . escape_html($last_backup) . "</div>"
        . "<div class='lbl'>" . get_text('last backup', 'Last Backup') . "</div></div>\n";
    print "</div>\n";

    print "<p class='fwbk-hint'>" . get_text('backup includes',
        'Each backup is a single compressed package (.tar.gz) with all firewall rules, NAT, custom hosts, networks, service and location groups.') . "</p>\n";

    # Create + Import side by side
    print "<div class='fwbk-cols'>\n";

    # Create
    print "  <div class='fwbk-card'>\n";
    print "    <h3>" . get_text('create new backup', 'Create New Backup') . "</h3>\n";
    print "    <form method='post' action='$script'>\n";
    print "      <input type='hidden' name='ACTION' value='create_backup'>\n";
    print "      <input type='text' name='backup_comment' maxlength='255' placeholder='"
        . get_text('backup comment placeholder', 'e.g., Backup before updating NAT rules') . "'>\n";
    print "      <input class='fwbk-btn fwbk-btn-primary' type='submit' name='SUBMIT' value='"
        . get_text('create backup', 'Create Backup') . "'>\n";
    print "    </form>\n";
    print "  </div>\n";

    # Import
    print "  <div class='fwbk-card'>\n";
    print "    <h3>" . get_text('import backup', 'Import Backup') . "</h3>\n";
    print "    <form method='post' action='$script' enctype='multipart/form-data'>\n";
    print "      <input type='hidden' name='ACTION' value='import_backup'>\n";
    print "      <input type='file' name='import_file' accept='.gz,.tgz,application/gzip,application/octet-stream'>\n";
    print "      <input class='fwbk-btn fwbk-btn-primary' type='submit' name='SUBMIT' value='"
        . get_text('import', 'Import') . "'>\n";
    print "      <div class='fwbk-hint' style='margin:7px 0 0'>" . get_text('import help',
        'Select a .tar.gz backup file previously exported from this or another IPFire system.') . "</div>\n";
    print "    </form>\n";
    print "  </div>\n";

    print "</div>\n";  # .fwbk-cols
    print "</div>\n";  # .fwbk
    &Header::closebox();

    # ===== Available backups =====
    &Header::openbox('100%', 'left', get_text('available backups', 'Available Backups'));
    print "<div class='fwbk'>\n";

    if (@backups) {
        print "<table class='fwbk-table'>\n";
        print "<tr>";
        print "<th>" . get_text('backup name', 'Backup Name') . "</th>";
        print "<th>" . get_text('timestamp', 'Date/Time') . "</th>";
        print "<th>" . get_text('size', 'Size') . "</th>";
        print "<th>" . get_text('comment', 'Comment') . "</th>";
        print "<th style='text-align:right'>" . get_text('actions', 'Actions') . "</th>";
        print "</tr>\n";

        my $restore_confirm = get_text('restore confirm', 'Are you sure you want to restore this backup?');
        my $delete_confirm  = get_text('delete confirm',  'Are you sure you want to delete this backup?');

        foreach my $backup (@backups) {
            my $name_e    = escape_html($backup->{name});
            my $ts_e      = escape_html($backup->{timestamp});
            my $size_e    = escape_html($backup->{size});
            my $comment_e = escape_html($backup->{comment});

            print "<tr>";
            print "<td class='fwbk-name'>$name_e</td>";
            print "<td>$ts_e</td>";
            print "<td>$size_e</td>";
            print "<td class='fwbk-comment'>$comment_e</td>";
            print "<td class='fwbk-actions2'>";

            print "<form method='post' action='$script'>"
                . "<input type='hidden' name='ACTION' value='restore_backup'>"
                . "<input type='hidden' name='backup_name' value='$name_e'>"
                . "<input class='fwbk-btn fwbk-btn-restore' type='submit' name='SUBMIT' value='"
                . get_text('restore', 'Restore') . "' onclick='return confirm(\"$restore_confirm\")'>"
                . "</form>";

            print "<form method='post' action='$script'>"
                . "<input type='hidden' name='ACTION' value='download_backup'>"
                . "<input type='hidden' name='backup_name' value='$name_e'>"
                . "<input class='fwbk-btn fwbk-btn-export' type='submit' name='SUBMIT' value='"
                . get_text('export', 'Export') . "'>"
                . "</form>";

            print "<form method='post' action='$script'>"
                . "<input type='hidden' name='ACTION' value='delete_backup'>"
                . "<input type='hidden' name='backup_name' value='$name_e'>"
                . "<input class='fwbk-btn fwbk-btn-delete' type='submit' name='SUBMIT' value='"
                . get_text('delete', 'Delete') . "' onclick='return confirm(\"$delete_confirm\")'>"
                . "</form>";

            print "</td></tr>\n";
        }

        print "</table>\n";
    } else {
        print "<p class='fwbk-empty'>" . get_text('no backups available',
            'No backups available. Create your first backup using the form above.') . "</p>\n";
    }

    print "</div>\n";  # .fwbk
    &Header::closebox();
}
