#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A linux based firewall                                         #
# Copyright (C) 2007-2026  IPFire Team  <info@ipfire.org>                     #
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.       #
#                                                                             #
###############################################################################

use strict;
use JSON::PP;
use Net::LibIDN2 ':all';
use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename);

# enable only the following on debugging purpose
#use warnings;
#use CGI::Carp 'fatalsToBrowser';

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";
require "${General::swroot}/network-functions.pl";

my %color = ();
my %mainsettings = ();
my %settings = ();
my %cgiparams = ();
my %custom_domains = ();
my $dnsbl;

# Arrays which contain the custom defined domain names.
my @custom_allowed_domains = ();
my @custom_blocked_domains = ();

# File which contains the available filtering categories.
my $dnsbl_json_file = "${General::swroot}/dns/dnsbl.json";

# File wich contains the configured filtering rules.
my $settings_file = "${General::swroot}/dns/dnsbl";

# File which contains the elements of the custom allow and block lists.
my $custom_domains_file = "${General::swroot}/dns/custom_domains";

# File which contains user supplied RPZ feeds.  Keeping this separate from
# dnsbl.json prevents Core updates from overwriting locally configured feeds.
my $custom_dnsbl_json_file = "${General::swroot}/dns/custom_dnsbl.json";
my $rpz_directory = "/var/lib/knot-resolver/zones";

# Read-in main settings, for language, theme and colors.
&General::readhash("${General::swroot}/main/settings", \%mainsettings);
&General::readhash("/srv/web/ipfire/html/themes/ipfire/include/colors.txt", \%color);

# Get the available network zones, based on the config type of the system and store
# the list of zones in an array.
my @network_zones = &Network::get_available_network_zones();

# Get the available filter categories.
#
# Open the JSON file.
open(DNSBL, $dnsbl_json_file);

# Read-in the dnsbl.json file content and append the lines to a string.
my $json_file = join("\n", <DNSBL>);

# Close file handle.
close(DNSBL);

# Call the JSON parser to parse the dnsbl.json file content.
if ($json_file) {
	$dnsbl = decode_json($json_file);
}

# Append custom lists to the built-in catalogue at runtime.
my $custom_dnsbl = [];
if (-f $custom_dnsbl_json_file) {
	if (open(CUSTOM_DNSBL, $custom_dnsbl_json_file)) {
		my $custom_json = join("\n", <CUSTOM_DNSBL>);
		close(CUSTOM_DNSBL);
		eval { $custom_dnsbl = decode_json($custom_json) if ($custom_json); };
		$custom_dnsbl = [] if ($@ || ref($custom_dnsbl) ne "ARRAY");
	}
}
push(@{ $dnsbl }, @{ $custom_dnsbl });

my @errormessages = ();
my @infomessages = ();

&Header::showhttpheaders();

#Get GUI values
&Header::getcgihash(\%cgiparams);

# Add a custom RPZ feed.
if ($cgiparams{'ACTION'} eq "ADD_CUSTOM_LIST") {
	my $name = $cgiparams{'CUSTOM_LIST_NAME'} || "";
	my $url = $cgiparams{'CUSTOM_LIST_URL'} || "";
	my $description = $cgiparams{'CUSTOM_LIST_DESCRIPTION'} || "";
	my $license = $cgiparams{'CUSTOM_LIST_LICENSE'} || "";

	for ($name, $url, $description, $license) {
		s/^\s+|\s+$//g;
	}

	push(@errormessages, $Lang::tr{'dnsbl custom list name required'}) unless ($name);
	push(@errormessages, $Lang::tr{'dnsbl custom list url invalid'})
		unless ($url =~ m{^https://[A-Za-z0-9][A-Za-z0-9.:-]*(?:/[^\s]*)?$});
	push(@errormessages, $Lang::tr{'dnsbl custom list url exists'})
		if (grep { ($_->{'url'} || "") eq $url } @{ $custom_dnsbl });

	unless (@errormessages) {
		my $zone = "custom-" . substr(sha256_hex($url), 0, 16) . ".rpz";
		my $entry = {
			name => $name, zone => $zone, primary => "localhost",
			description => ($description || $Lang::tr{'dnsbl custom rpz list'}),
			license => $license, url => $url,
			custom => JSON::PP::true,
		};
		push(@{ $custom_dnsbl }, $entry);
		&write_custom_lists($custom_dnsbl_json_file, $custom_dnsbl);
		push(@{ $dnsbl }, $entry);

		&readsettings("$settings_file", \%settings);
		$settings{$zone} = [ "on", "", "", "", "" ];
		&writesettings("$settings_file", \%settings);
		&General::system_background("/usr/local/bin/dnsctrl", "sync-rpzs");
		push(@infomessages, "$Lang::tr{'dnsbl custom list added'}: $name");
	}

# Delete a custom RPZ feed.
} elsif ($cgiparams{'ACTION'} eq "DELETE_CUSTOM_LIST") {
	my $zone = $cgiparams{'ZONE'} || "";
	my ($item) = grep { $_->{'custom'} && $_->{'zone'} eq $zone } @{ $custom_dnsbl };
	if ($item) {
		@{ $custom_dnsbl } = grep { $_->{'zone'} ne $zone } @{ $custom_dnsbl };
		&write_custom_lists($custom_dnsbl_json_file, $custom_dnsbl);
		&readsettings("$settings_file", \%settings);
		delete($settings{$zone});
		&writesettings("$settings_file", \%settings);
		unlink("${rpz_directory}/${zone}.zone");
		unlink("${rpz_directory}/.${zone}.last-attempt");
		unlink("${rpz_directory}/.${zone}.etag");
		@{ $dnsbl } = grep { $_->{'zone'} ne $zone } @{ $dnsbl };
		&General::system_background("/usr/local/bin/dnsctrl", "reload");
		push(@infomessages, "$Lang::tr{'dnsbl custom list deleted'}: " . $item->{'name'});
	} else {
		push(@errormessages, $Lang::tr{'dnsbl custom list delete not found'});
	}

# Save settings on main page.
} elsif ($cgiparams{'ACTION'} eq "$Lang::tr{'save'}") {
	my %tmphash;

	# Read-in settings file.
	&readsettings("$settings_file", \%settings);

	# Loop through the list of known blocklists.
	foreach my $list (@{ $dnsbl }) {
		# Assign stored or default values.
		my $zone = $list->{'zone'};
		my $enabled = $cgiparams{$zone} || "";
		my $comment = $settings{$zone}[1] || "";
		my $enabled_zones = $settings{$zone}[2] || "";
		my $custom_acl = $settings{$zone}[3] || "";
		my $rest = $settings{$zone}[4] || "";

		# Store the current list and the assigned array values in the temporary hash.
		$tmphash{$zone} = [ "$enabled", "$comment", "$enabled_zones", "$custom_acl", "$rest" ];
	}

	# Write config hash.
	&writesettings("$settings_file", \%tmphash);

	# Sync RPZs
	&General::system_background("/usr/local/bin/dnsctrl", "sync-rpzs");

# Save changed zone ACL
} elsif ($cgiparams{'ACTION'} eq "$Lang::tr{'update'}") {
	my %tmphash;
	my $old_zone = $cgiparams{'ZONE'} || "";
	my $new_name = $cgiparams{'LIST_NAME'} || "";
	my $new_zone = $cgiparams{'LIST_ZONE'} || "";
	my $new_primary = $cgiparams{'LIST_PRIMARY'} || "";
	my $new_description = $cgiparams{'LIST_DESCRIPTION'} || "";
	my $new_license = $cgiparams{'LIST_LICENSE'} || "";
	my $new_url = $cgiparams{'LIST_URL'} || "";
	for ($new_name, $new_zone, $new_primary, $new_description, $new_license, $new_url) {
		s/^\s+|\s+$//g;
	}
	my $edited_list = &get_list($old_zone);
	push(@errormessages, $Lang::tr{'dnsbl custom list edit not found'}) unless ($edited_list);

	# Built-in catalogue metadata is read-only.  Always use the trusted values
	# instead of accepting altered fields from a forged POST request.
	if ($edited_list && !$edited_list->{'custom'}) {
		$new_name = $edited_list->{'name'};
		$new_zone = $edited_list->{'zone'};
		$new_primary = $edited_list->{'primary'};
		$new_description = $edited_list->{'description'};
		$new_license = $edited_list->{'license'};
	}
	push(@errormessages, $Lang::tr{'dnsbl custom list name required'}) unless ($new_name);
	push(@errormessages, $Lang::tr{'dnsbl custom list zone invalid'})
		unless ($new_zone =~ /^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$/);
	push(@errormessages, $Lang::tr{'dnsbl custom list primary required'}) unless ($new_primary);
	push(@errormessages, $Lang::tr{'dnsbl custom list zone exists'})
		if ($new_zone ne $old_zone && grep { $_->{'zone'} eq $new_zone } @{ $dnsbl });
	if ($edited_list && $edited_list->{'custom'}) {
		push(@errormessages, $Lang::tr{'dnsbl custom list url invalid'})
			unless ($new_url =~ m{^https://[A-Za-z0-9][A-Za-z0-9.:-]*(?:/[^\s]*)?$});
		push(@errormessages, $Lang::tr{'dnsbl custom list url exists'})
			if (grep { $_->{'zone'} ne $old_zone && ($_->{'url'} || "") eq $new_url } @{ $custom_dnsbl });
	}

	# Assign ACL to arrays.
	my @enabled_zones = split(/\|/, $cgiparams{'ENABLED_ZONES'});
	my @custom_acl = split(/\s+/, $cgiparams{'CUSTOM_ACL'});

	# Check if the given network zones are valid.
	foreach my $enabled_zone (@enabled_zones) {
		# Convert the current processed enabled zone into lower case format.
		my $enabled_zone_lc = lc($enabled_zone);

		# Check if the zone is known.
		unless (grep(/$enabled_zone_lc/, @network_zones)) {
			# Display error message about unknown network zone.
			push(@errormessages, "$enabled_zone - $Lang::tr{'unknown network zone'}");
		}
	}

	# Check if the given custom ACL addresses/networks are valid.
	foreach my $address (@custom_acl) {
		next unless($address);

		if ((!&Network::check_ip_address($address)) && (!&Network::check_subnet($address))) {
			push(@errormessages, "$address - $Lang::tr{'guardian invalid address or subnet'}");
		}
	}

	# Normalize all networks
	@custom_acl = &Network::normalize_networks(@custom_acl);

	# Only go further, if there was no error message.
	unless (scalar @errormessages) {
		# Read-in settings file.
		&readsettings("$settings_file", \%settings);

		# Assign nice human read-able variables.
		my $zone = $old_zone;
		my $enabled = $settings{$zone}[0];
		my $comment = $settings{$zone}[1];
		my $enabled_zones = join("|", @enabled_zones);
		my $custom_acl = join("|", @custom_acl);
		my $rest = $settings{$zone}[4];

		# Copy stored settings into temporary hash.
		%tmphash = %settings;

		# Update the values in the temporay hash.
		delete($tmphash{$zone}) if ($new_zone ne $zone);
		$tmphash{$new_zone} = [ "$enabled", "$comment", "$enabled_zones", "$custom_acl", "$rest" ];

		# Write the new ACL settings to settings file.
		&writesettings("$settings_file", \%tmphash);

		# Only custom catalogue metadata may be changed.
		if ($edited_list->{'custom'}) {
			my $old_url = $edited_list->{'url'} || "";
			foreach my $item (@{ $custom_dnsbl }) {
				next unless ($item->{'zone'} eq $old_zone);
				$item->{'name'} = $new_name;
				$item->{'zone'} = $new_zone;
				$item->{'primary'} = $new_primary;
				$item->{'description'} = $new_description;
				$item->{'license'} = $new_license;
				$item->{'url'} = $new_url;
				delete($item->{'update_interval'});
				last;
			}
			&write_custom_lists($custom_dnsbl_json_file, $custom_dnsbl);
			if ($new_url ne $old_url || $new_zone ne $old_zone) {
				unlink("${rpz_directory}/.${old_zone}.last-attempt");
				unlink("${rpz_directory}/.${old_zone}.etag");
			}
		}

		if ($new_zone ne $old_zone && -f "${rpz_directory}/${old_zone}.zone") {
			rename("${rpz_directory}/${old_zone}.zone", "${rpz_directory}/${new_zone}.zone");
		}

		# Reload DNS
		&General::system_background("/usr/local/bin/dnsctrl", "sync-rpzs");
		push(@infomessages, ($edited_list->{'custom'} ? $Lang::tr{'dnsbl custom list updated'} : $Lang::tr{'dnsbl acl updated'}) . ": $new_name");
	}

# Save changed custom domains to allow or block
} elsif ($cgiparams{'CUSTOM_DOMAINS'} eq "$Lang::tr{'save'}") {
	my @cgi_allowed_domains;
	my @cgi_blocked_domains;
	my @ascii_allowed_domains;
	my @ascii_blocked_domains;

	# Get the current configured custom domains to allow or block
	&readsettings("$custom_domains_file", \%custom_domains) if (-f "$custom_domains_file");

	# Grab custom configured domains and assign them to the corresponding arrays.
	@custom_allowed_domains = @{ $custom_domains{"CUSTOM_ALLOWED_DOMAINS"} } if ($custom_domains{"CUSTOM_ALLOWED_DOMAINS"});
	@custom_blocked_domains = @{ $custom_domains{"CUSTOM_BLOCKED_DOMAINS"} } if ($custom_domains{"CUSTOM_BLOCKED_DOMAINS"});

	# Assign the posted domains from cgi to the corresponding arrays.
	@cgi_allowed_domains = split(/\s+/, $cgiparams{"CUSTOM_ALLOWED_DOMAINS"});
	@cgi_blocked_domains = split(/\s+/, $cgiparams{"CUSTOM_BLOCKED_DOMAINS"});

	# Remove any duplicate entries from the arrays.
	@cgi_allowed_domains = &General::uniq(@cgi_allowed_domains);
	@cgi_blocked_domains = &General::uniq(@cgi_blocked_domains);

	# Check domains and convert into ascii format.
	@ascii_allowed_domains = &format_domains(\@cgi_allowed_domains, "ascii");
	@ascii_blocked_domains = &format_domains(\@cgi_blocked_domains, "ascii");

	# Merge temporary merge both arrays for duplicate and valid check.
	my @ascii_merged = (@ascii_allowed_domains, @ascii_blocked_domains);

	# Check if there are duplicate entries on the merged list.
	# This assumes a domain which has been entered on both
	my $dup = &check_for_duplicates(@ascii_merged);

	# If a duplicate has been found, raise an error
	if ($dup) {
		push(@errormessages, "$dup - $Lang::tr{'dnsbl error domain specified twice'}");
	}

	# Check allowed domains
	foreach my $domain (@ascii_allowed_domains) {
		unless (&General::validfqdn($domain)) {
			push(@errormessages, "$Lang::tr{'invalid domain name'}: ${domain}");
		}
	}

	# Check blocked domains
	foreach my $domain (@ascii_blocked_domains) {
		unless (&General::validfqdn($domain)) {
			push(@errormessages, "$Lang::tr{'invalid domain name'}: ${domain}");
		}
	}

	# Check if a domain from the posted blocked domains array is allready part of
	# the saved allowed domains array
	$dup = &compare_arrays(\@custom_allowed_domains, \@ascii_blocked_domains);
	if ($dup) {
		push(@errormessages, "$dup - $Lang::tr{'dnsbl error domain specified twice'}");
	}

	# Check if a domain from the posted allowed domains array is allready part of
	# the saved blocked domains array.
	$dup = &compare_arrays(\@custom_blocked_domains, \@ascii_allowed_domains);
	if ($dup) {
		push(@errormessages, "$dup - $Lang::tr{'dnsbl error domain specified twice'}");
	}

	unless (scalar @errormessages) {
		my %tmp;

		# Assign the allowed and blocked domain arrays to the temporary hash
		foreach my $domain (@ascii_allowed_domains) {
			$tmp{$domain} = [ "allowed" ];
		}

		foreach my $domain (@ascii_blocked_domains) {
			$tmp{$domain} = [ "blocked" ];
		}

		# Save the domains
		&writesettings("$custom_domains_file", \%tmp);

		# Reload DNS
		&General::system_background("/usr/local/bin/dnsctrl", "reload");
	}
}

&Header::openpage($Lang::tr{"dnsbl dns firewall"}, 1, '');

&Header::openbigbox('100%', 'left');

# Display any error messages
&Header::errorbox(@errormessages);
if (@infomessages) {
	&Header::openbox('100%', 'left', $Lang::tr{'information'});
	print join("<br>\n", map { &html_escape($_) } @infomessages);
	&Header::closebox();
}

# Decide which page should be displayed.
if ($cgiparams{'ACTION'} eq "$Lang::tr{'edit'}" ||
	($cgiparams{'ACTION'} eq "$Lang::tr{'update'}" && @errormessages)) {
	&show_edit_zone();
} elsif ($cgiparams{'ACTION'} eq "SHOW_ADD_CUSTOM_LIST" ||
	($cgiparams{'ACTION'} eq "ADD_CUSTOM_LIST" && @errormessages)) {
	&show_add_custom_list();
} else {
	&show_mainpage();
}

&Header::closebigbox();
&Header::closepage();

#
## Function to display the main page.
#
sub show_mainpage() {
	# Read-in settings file
	&readsettings("$settings_file", \%settings);

	# Read-in custom allow and blocklist file.
	&readsettings("$custom_domains_file", \%custom_domains) if (-f "$custom_domains_file");

	# Grab the list elements and assign them to the corresponding arrays
	if (%custom_domains) {
		foreach my $domain (keys %custom_domains) {
			my $status = $custom_domains{$domain}[0];

			if ($status eq "allowed") {
				push(@custom_allowed_domains, &format_domain_to_unicode($domain));
			} elsif ($status eq "blocked") {
				push(@custom_blocked_domains, &format_domain_to_unicode($domain));
			}
		}
	}

	&Header::openbox('100%', 'center', $Lang::tr{"dnsbl lists"});

print <<END;
	<form id='main' method='post' action='$ENV{'SCRIPT_NAME'}'></form>
	<table width='100%' border='0' class='tbl'>
END
        	# Loop through the available blocklists.
        	foreach my $list (@{ $dnsbl }) {
			my $name = &html_escape($list->{"name"});
			my $description = &html_escape($list->{"description"});
			my $zone = $list->{"zone"};
			my $form_id = "list-" . substr(sha256_hex($zone), 0, 16);
			my $checked;

			# Check if the list is enabled.
			if ($settings{$zone}[0] eq "on") {
				$checked = "checked='checked'";
			}

print <<END;
		<tr>
			<td width='5%' class="text-center">
				<input type='checkbox' form='main' name='$zone' id='$zone' value='on' $checked>
			</td>
			<td width='20%'>
				<strong>$name</strong>
			</td>
			<td width='70%'>$description</td>
			<td width='5%' align='center' style='white-space: nowrap;'>
				<form id='$form_id' method='post' action='$ENV{'SCRIPT_NAME'}' style='display:none'></form>
				<input type='hidden' form='$form_id' name='ACTION' value='$Lang::tr{'edit'}'>
				<input type='image' form='$form_id' name='$Lang::tr{'edit'}' src='/images/edit.gif' alt='$Lang::tr{'edit'}' title='$Lang::tr{'edit'}' style='vertical-align:middle'>
				<input type='hidden' form='$form_id' name='ZONE' value='$zone'>
				@{[ $list->{'custom'} ? "<form id='delete-$zone' method='post' action='$ENV{'SCRIPT_NAME'}' style='display:none'></form><input type='hidden' form='delete-$zone' name='ZONE' value='$zone'><input type='hidden' form='delete-$zone' name='ACTION' value='DELETE_CUSTOM_LIST'><input type='image' form='delete-$zone' src='/images/delete.gif' alt='$Lang::tr{'delete'}' title='$Lang::tr{'dnsbl custom list delete'}' style='vertical-align:middle' onclick=\"return confirm('$Lang::tr{'dnsbl custom list delete confirm'}');\">" : "" ]}
			</td>
		</tr>
END
		}

print <<END;

	</table>

	<br>

	<div align='right'>
		<button type='submit' form='show-add-list' name='ACTION' value='SHOW_ADD_CUSTOM_LIST'>$Lang::tr{'add'}</button>
		<input type='submit' form='main' name='ACTION' value='$Lang::tr{'save'}'>
		<form id='show-add-list' method='post' action='$ENV{'SCRIPT_NAME'}'></form>
	</div>
END

	&Header::closebox();

	# Section for custom allow and blocklist.
	&Header::openbox('100%', 'center', $Lang::tr{"dnsbl custom block and allow list"});

print <<END;
	<form method='post' action='$ENV{'SCRIPT_NAME'}'>
		<table class="form">
			<tr>
				<td>
					$Lang::tr{"urlfilter blocked domains"}
				</td>

				<td>
					<textarea name='CUSTOM_BLOCKED_DOMAINS' rows='8'
						>@{[ join("\n", @custom_blocked_domains) ]}</textarea>
				</td>
			</tr>

			<tr>
				<td>
					$Lang::tr{"urlfilter allowed domains"}
				</td>

				<td>
					<textarea name='CUSTOM_ALLOWED_DOMAINS' rows='8'
						>@{[ join("\n", @custom_allowed_domains) ]}</textarea>
				</td>
			</tr>

			<tr class="action">
				<td colspan="2">
					<input type='submit' name='CUSTOM_DOMAINS' value='$Lang::tr{'save'}'>
				</td>
			</tr>
		</table>
	</form>
END

	&Header::closebox();
}

sub show_add_custom_list() {
	&Header::openbox('100%', 'center', $Lang::tr{'dnsbl custom list add'});
print <<END;
	<form method='post' action='$ENV{'SCRIPT_NAME'}'>
		<table class='form'>
			<tr><td width='25%'>$Lang::tr{'dnsbl custom list name'}</td><td><input type='text' name='CUSTOM_LIST_NAME' required maxlength='80' value='@{[ &html_escape($cgiparams{'CUSTOM_LIST_NAME'}) ]}'></td></tr>
			<tr><td>$Lang::tr{'dnsbl custom list url'}</td><td><input type='url' name='CUSTOM_LIST_URL' required placeholder='https://example.org/list.rpz' value='@{[ &html_escape($cgiparams{'CUSTOM_LIST_URL'}) ]}'></td></tr>
			<tr><td>$Lang::tr{'description'}</td><td><input type='text' name='CUSTOM_LIST_DESCRIPTION' maxlength='200' value='@{[ &html_escape($cgiparams{'CUSTOM_LIST_DESCRIPTION'}) ]}'></td></tr>
			<tr><td>$Lang::tr{'dnsbl custom list license'}</td><td><input type='text' name='CUSTOM_LIST_LICENSE' maxlength='100' value='@{[ &html_escape($cgiparams{'CUSTOM_LIST_LICENSE'}) ]}'></td></tr>
			<tr><td colspan='2'><small>$Lang::tr{'dnsbl custom list help'}</small></td></tr>
			<tr class='action'><td colspan='2'><button type='submit' name='ACTION' value='BACK' formnovalidate>$Lang::tr{'back'}</button> <button type='submit' name='ACTION' value='ADD_CUSTOM_LIST'>$Lang::tr{'dnsbl custom list add'}</button></td></tr>
		</table>
	</form>
END
	&Header::closebox();
}

#
## Function to show section to edit the zone ACL.
#
sub show_edit_zone() {
	# Get the requested zone.
	my $zone = $cgiparams{'ZONE'};

	# Fetch the list
	my $list = &get_list($zone);

	# Fail if we could not find the list
	die "Unknown list: $zone" unless (defined $list);

	# Read-in settings file.
	&readsettings("$settings_file", \%settings);

	# Grab the configured ACL settings.
	my @enabled_zones = split(/\|/, $settings{$zone}[2]);
	my @custom_acl = split(/\|/, $settings{$zone}[3]);
	my $name = &html_escape($list->{'name'});
	my $list_zone = &html_escape($list->{'zone'});
	my $primary = &html_escape($list->{'primary'});
	my $description = &html_escape($list->{'description'});
	my $license = &html_escape($list->{'license'});
	my $url = &html_escape($list->{'url'});
	my $readonly = $list->{'custom'} ? "" : " readonly='readonly'";

	&Header::openbox('100%', 'center', $list->{"name"});

print <<END;
	<form method='post' action='$ENV{'SCRIPT_NAME'}'>
		<input type='hidden' name='ZONE' value='$zone'>

		<table class="form">
			<tr class="header"><td colspan="2">$Lang::tr{'dnsbl list information'}</td></tr>
			<tr><td>$Lang::tr{'name'}</td><td><input type='text' name='LIST_NAME' value='$name' required maxlength='80'$readonly></td></tr>
			<tr><td>$Lang::tr{'dnsbl list zone'}</td><td><input type='text' name='LIST_ZONE' value='$list_zone' required maxlength='253'$readonly></td></tr>
			<tr><td>$Lang::tr{'dnsbl list primary'}</td><td><input type='text' name='LIST_PRIMARY' value='$primary' required maxlength='253'$readonly></td></tr>
			@{[ $list->{'custom'} ? "<tr><td>$Lang::tr{'dnsbl custom list url'}</td><td><input type='url' name='LIST_URL' value='$url' required maxlength='2048'></td></tr>" : "" ]}
			<tr><td>$Lang::tr{'description'}</td><td><input type='text' name='LIST_DESCRIPTION' value='$description' maxlength='200'$readonly></td></tr>
			<tr><td>$Lang::tr{'dnsbl custom list license'}</td><td><input type='text' name='LIST_LICENSE' value='$license' maxlength='100'$readonly></td></tr>
			@{[ $list->{'custom'} ? "" : "<tr><td colspan='2'><small>$Lang::tr{'dnsbl official list readonly'}</small></td></tr>" ]}
			<tr class="header">
				<td colspan="2">
					$Lang::tr{"dnsbl acl"}
				</td>
			</tr>

			<tr>
				<td colspan="2">
					<p>
						$Lang::tr{'dnsbl acl explanation'}
					</p>
				</td>
			</tr>

			<tr>
				<td>
					$Lang::tr{"network zone"}
				</td>

				<td>
					<select name="ENABLED_ZONES" size='6' multiple>
END

					# Loop through the array of available network zones.
					foreach my $zone (@network_zones) {
						my $selected;

						# Skip the red network zone.
						next if ($zone) eq "red";

						# Convert zone name into upper case format.
						my $zone_uc = uc($zone);

						# Check if the current processed zone previously has been
						# selected.
						if ( grep( /$zone_uc/, @enabled_zones ) ) {
							$selected = "selected";
						}

						print "<option value='$zone_uc' $selected>$Lang::tr{$zone}</option>\n";
					}
print <<END;
					</select>
				</td>
			</tr>

			<tr>
				<td>
					$Lang::tr{"dnsbl custom source"}
				</td>

				<td>
					<textarea name='CUSTOM_ACL' rows='9' placeholder='1.2.3.4\n10.0.0.0/255.255.255.0\n192.168.0.0/24'
						>@{[ join("\n", @custom_acl) ]}</textarea>
				</td>
			</tr>

			<tr class="action">
				<td colspan='2'>
					<input type='submit' value='$Lang::tr{'back'}' formnovalidate>
					<input type='submit' name='ACTION' value='$Lang::tr{'update'}'>
				</td>
			</tr>
		</table>
	</form>
END

	&Header::closebox();
}

#
## Custom readsettings function to allow non numerical key instead an id.
#
sub readsettings {
	my ($filename, $hash) = @_;
	%$hash = ();

	open(FILE, $filename) or die "Unable to read file $filename";

	while (<FILE>) {
		my ($key, $rest, @temp);
		chomp;
		($key, $rest) = split (/,/, $_, 2);
		@temp = split (/,/, $rest);
		$hash->{$key} = \@temp;
	}
	close FILE;
	return;
}

#
## Custom writesettings function to allow a non numerical key instead an id.
#
sub writesettings {
	my ($filename, $hash) = @_;
	my ($key, @temp, $i);

	open(FILE, ">$filename") or die "Unable to write to file $filename";

	foreach $key (keys %$hash) {
		print FILE "$key";
		foreach $i (0 .. $#{$hash->{$key}}) {
			print FILE ",$hash->{$key}[$i]";
		}
		print FILE "\n";
	}
	close FILE;
	return;
}

sub write_custom_lists {
	my ($filename, $lists) = @_;
	my $tmp = "${filename}.tmp.$$";
	open(my $fh, ">", $tmp) or die "Unable to write $tmp: $!";
	print $fh JSON::PP->new->utf8->pretty->canonical->encode($lists);
	close($fh) or die "Unable to close $tmp: $!";
	chmod(0644, $tmp);
	rename($tmp, $filename) or die "Unable to replace $filename: $!";
}

sub write_json_file {
	my ($filename, $data) = @_;
	my $tmp = "${filename}.tmp.$$";
	open(my $fh, ">", $tmp) or die "Unable to write $tmp: $!";
	print $fh JSON::PP->new->utf8->pretty->canonical->encode($data);
	close($fh) or die "Unable to close $tmp: $!";
	my @stat = stat($filename);
	chmod($stat[2] & 07777, $tmp) if (@stat);
	chown($stat[4], $stat[5], $tmp) if (@stat);
	rename($tmp, $filename) or die "Unable to replace $filename: $!";
}

sub html_escape {
	my ($text) = @_;
	$text = "" unless defined($text);
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	$text =~ s/'/&#39;/g;
	return $text;
}

sub get_list($) {
	my $zone = shift;

	foreach my $list (@{ $dnsbl }) {
		return $list if ($list->{"zone"} eq $zone);
	}

	return undef;
}

sub check_for_duplicates (@) {
	my @array = @_;
	my $lastelement;

	# Sort and loop through the given array.
	foreach my $element (sort(@array)) {
		# Check if the current element is the same than the last one.
		return $element if ($element eq $lastelement);

		# Store last processed element.
		$lastelement = $element;
	}
}

sub compare_arrays (\@\@) {
	my ($data, $test) = @_;

	my @data = @{ $data };
	my @test = @{ $test };

	# Early exit if there are no entries in one of the given arrays.
	return unless (@data);
	return unless (@test);

	# Loop through the content of the test array and check
	# if the current processed element is part of the data array.
	foreach my $element (@test) {
		if (grep(/$element/, @data)) {
			return "$element";
		}
	}
}

sub format_domains(\@$) {
	my ($arrayref, $format) = @_;
	my @formated_domains;

	# Deref and assign array.
	my @domains = @{ $arrayref };

	# Exit if not data passed.
	return unless (@domains);

	# Loop through the given domains array.
	foreach my $domain (@domains) {
		my $formated_domain;

		# Check the output format and convert the domain into requested format.
		if ($format eq "ascii") {
			$formated_domain = &format_domain_to_ascii($domain);
		} elsif ($format eq "unicode") {
			$formated_domain = &format_domain_to_unicode($domain);
		} else {
			# Unknown format requested.
			return;
		}

		# Check if the domain could be converted.
		if ($formated_domain) {
			# Add the converted domain to the array of ascii domains.
			push(@formated_domains, $formated_domain);
		} else {
			# Add the invalid domain to the array of error messages.
			push(@errormessages, "$domain - $Lang::tr{'invalid domain name'}");
		}
	}

	return @formated_domains;
}

sub format_domain_to_ascii($) {
	my ($domain) = @_;
	my $ascii;
	my $ret;

	# Early exit on empty input.
	return unless($domain);

	# Spit the given domain name into parts.
	my @parts = split(/\./, $domain);

	# Exit if the given domain does not contain at least one dot.
	return if(scalar(@parts) < 2);

	# Use the perl module to convert the domain into the idn ascii format.
	$ascii = &Net::LibIDN2::idn2_to_ascii_8($domain, "", $ret);

	# Check if an error occured.
	if ($ret) {
		# Get the error message.
		my $error = &Net::LibIDN2::idn2_strerror($ret);

		push(@errormessages, "$domain - LibIDN2: $error");
	}

	# Exit if the given domain could not be converted.
	return unless($ascii);

	# Return the converted domain.
	return $ascii;
}

sub format_domain_to_unicode($) {
	my ($ascii) = @_;
	my $unicode;
	my $ret;

	# Exit if no input has been given.
	return unless($ascii);

	# Convert the idn_ascii formated domain back to unicode and return it.
	$unicode = &Net::LibIDN2::idn2_to_unicode_88($ascii, $ret);

	# Check if an error occured.
	if ($ret) {
		# Get the error message.
		my $error = &Net::LibIDN2::idn2_strerror($ret);

		push(@errormessages, "$ascii - LibIDN2: $error");
	}

	return $unicode;
}
