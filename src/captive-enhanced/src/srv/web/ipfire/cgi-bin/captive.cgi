#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A linux based firewall                                         #
# Copyright (C) 2016  IPFire Team  <alexander.marx@ipfire.org>                #
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
#Versione del 24-09-2026 ora 09.30
#versione 1.05
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################

#use strict;
use Encode;
use CGI ();
use constant LOGO_MAX_BYTES => 2 * 1024 * 1024;
use constant LOGO_REQUEST_MAX => LOGO_MAX_BYTES + 256 * 1024;
use HTML::Entities();
use File::Basename;
use File::LibMagic;
use File::Copy;
use File::Temp qw(tempfile);
require '/var/ipfire/captive-lib.pl';
Captive::management();
$CGI::POST_MAX = LOGO_REQUEST_MAX;
if (($ENV{'REQUEST_METHOD'} // '') eq 'POST' && ($ENV{'CONTENT_LENGTH'} // 0) > LOGO_REQUEST_MAX) {
    Captive::fail('413 Payload Too Large','logo_too_large');
}
$CGI::DISABLE_UPLOADS = 0;
my $state_lock = Captive::lock();
my $csrf_token = Captive::csrf('management');

# enable only the following on debugging purpose
#use warnings;
#use CGI::Carp 'fatalsToBrowser';

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";
Lang::reload('en') unless $Lang::tr{'save'};
Captive::fail('500 Internal Server Error', 'language_unavailable') unless $Lang::tr{'save'} && $Lang::tr{'Captive generate coupons'};

my %session_times = (
	3600		=> $Lang::tr{'one hour'},
	14400		=> $Lang::tr{'four hours'},
	28800		=> $Lang::tr{'eight hours'},
	43200		=> $Lang::tr{'twelve hours'},
	86400		=> $Lang::tr{'24 hours'},
	604800		=> $Lang::tr{'one week'},
	1209600		=> $Lang::tr{'two weeks'},
	2592000 	=> $Lang::tr{'one month'},
	31536000	=> $Lang::tr{'one year'},
	0		=> "- $Lang::tr{'unlimited'} -",
);

my %selected = ();

my $coupons = "${General::swroot}/captive/coupons";
my %couponhash = ();

my $logo = "${General::swroot}/captive/logo.dat";
my $logotmp;

my %settings=();
my %mainsettings;
my %color;
my %cgiparams=();
my %netsettings=();
my %checked=();
my $errormessage='';
my $clients="${General::swroot}/captive/clients";
my %clientshash=();
my $settingsfile="${General::swroot}/captive/settings";
unless (-e $settingsfile)	{ &General::system("touch $settingsfile"); }

&Header::getcgihash(\%cgiparams, {wantfile => 1, filevar => 'logo'});
if (my $cgi_error=$cgiparams{'__CGI__'}->cgi_error) {
    Captive::fail($cgi_error =~ /^413/ ? '413 Payload Too Large' : '400 Bad Request', $cgi_error =~ /^413/ ? 'logo_too_large' : 'invalid_request');
}
if (($ENV{'REQUEST_METHOD'} // '') eq 'POST') {
    Captive::fail('403 Forbidden', 'invalid_csrf')
        unless Captive::check_csrf('management', $cgiparams{'CSRF_TOKEN'});
}


&General::readhash("${General::swroot}/main/settings", \%mainsettings);
&General::readhash("/srv/web/ipfire/html/themes/ipfire/include/colors.txt", \%color);
&General::readhash("$settingsfile", \%settings) if(-f $settingsfile);
&General::readhash("${General::swroot}/ethernet/settings", \%netsettings);
my @coupon_languages = Captive::coupon_languages();
my %coupon_languages = map { $_->[0] => $_->[1] } @coupon_languages;

if ($cgiparams{'ACTION'} eq "export-coupons") {
	my $pdf = &generate_pdf();

	print "Cache-Control: no-store\nContent-Type: application/pdf\n";
	print "Content-Disposition: attachment; filename=captive-portal-coupons.pdf\n";
	print "\n"; # end headers

	# Send PDF
	print $pdf;

	exit(0);
}


$settings{'COLOR'} = '#ff6600' unless ($settings{'COLOR'} // '') =~ /^#[0-9a-fA-F]{6}\z/;

if ($cgiparams{'ACTION'} eq $Lang::tr{'save'}) {
	my $file = $cgiparams{'logo'};
	if ($file) {
		chomp $file;
		# Save logo to /tmp/ to carry out content type check
		my ($filehandle) = CGI::upload("logo");
        Captive::fail('400 Bad Request', 'invalid_logo_upload') unless $filehandle;
		my ($tmpfh, $tmpname) = tempfile(".logo-XXXXXXXX", DIR => "/var/ipfire/captive", UNLINK => 1);
        $logotmp = $tmpname;
        open(FILE, ">&", $tmpfh) or die "Cannot open logo temporary file";
        binmode FILE;
		binmode $filehandle;
        my $uploaded_bytes=0;
        while (1) {
            my $read=read($filehandle,my $chunk,8192);
            die 'Cannot read uploaded logo' unless defined $read;
            last unless $read;
            $uploaded_bytes+=$read;
            if ($uploaded_bytes > LOGO_MAX_BYTES) {
                close(FILE); unlink $logotmp;
                Captive::fail('413 Payload Too Large','logo_too_large');
            }
            print FILE $chunk or die 'Cannot write uploaded logo';
        }
        close(FILE) or die 'Cannot close uploaded logo';
		# Check if the file content type is PNG or JPEG
		my $magic = File::LibMagic->new;
		my $file_info = $magic->info_from_filename($logotmp);
		my $file_mime_type = $file_info->{mime_type};
		if ($file_mime_type ne "image/png" && $file_mime_type ne "image/jpeg") {
			$errormessage = $Lang::tr{'Captive wrong type'}." - ".$file_mime_type;
			# Remove temporary logo file if there was an error.
			unlink $logotmp;
		}

	}

	$settings{'AUTH'}				= $cgiparams{'AUTH'};
	$settings{'TITLE'}			= $cgiparams{'TITLE'};
	$settings{'COLOR'}			= $cgiparams{'COLOR'};

	# SSID is mandatory and is stored in the captive settings file.
	my $ssid = $cgiparams{'ssid'} // '';
	$ssid =~ s/^\s+|\s+\z//g;
	if (length($ssid) > 32) {
		$errormessage = Captive::tr('ssid_too_long');
	} else {
		$settings{'ssid'} = $ssid;
	}
	
	$settings{'SESSION_TIME'} = $cgiparams{'SESSION_TIME'} // $settings{'SESSION_TIME'} // '0';
    for my $zone ('GREEN', 'BLUE') {
        if (!$netsettings{"${zone}_DEV"}) {
            $settings{"ENABLE_$zone"} = 'off';
        } elsif (exists $cgiparams{"ENABLE_${zone}_PRESENT"}) {
            # A current form explicitly represents both checked and unchecked.
            $settings{"ENABLE_$zone"} = ($cgiparams{"ENABLE_$zone"} // '') eq 'on' ? 'on' : 'off';
        } else {
            # Old/stale forms have no presence marker. Preserve the live value
            # instead of silently disabling a zone while changing other fields.
            $settings{"ENABLE_$zone"} = ($settings{"ENABLE_$zone"} // '') eq 'off' ? 'off' : 'on';
        }
    }
    $errormessage = Captive::tr('invalid_auth') unless ($settings{'AUTH'} // '') =~ /^(COUPON|TERMS)\z/;
    $errormessage = Captive::tr('invalid_duration') unless Captive::duration($settings{'SESSION_TIME'});
    $errormessage = Captive::tr('invalid_color') unless ($settings{'COLOR'} // '') =~ /^#[0-9a-fA-F]{6}\z/;
    $errormessage = Captive::tr('invalid_title_ssid')
        if length($settings{'TITLE'} // '') > 200 || ($settings{'TITLE'} // '') =~ /[\r\n\x00]/ ||
           length($ssid) > 32 || $ssid =~ /[\r\n\x00]/;
    $settings{'company'} = $cgiparams{'company'} // '';
    $settings{'translate'} = $cgiparams{'translate'} // $settings{'translate'} // 'en';
    delete $settings{'traslate'};
    $errormessage = Captive::tr('invalid_company_language') if length($settings{'company'}) > 200 || $settings{'company'} =~ /[\r\n\x00]/ || ($settings{'translate'} ne 'auto' && !exists $coupon_languages{$settings{'translate'}});
    $errormessage = Captive::tr('terms_too_long') if length($cgiparams{'TERMS'} // '') > 131072;


	if (!$errormessage){
		#Check if we need to upload a new logo
		if ($file) {
			# Move uploaded logo file from /tmp/
			File::Copy::move $logotmp, $logo;
		}

		Captive::write_settings($settingsfile, \%settings);

        Captive::atomic_text('/var/ipfire/captive/terms.txt', $cgiparams{'TERMS'} // '');

		#execute binary to reload firewall rules
		$errormessage = Captive::tr('firewall_reload_failed') unless Captive::reload();

		if ($netsettings{'BLUE_DEV'}){
				$errormessage = Captive::tr('wireless_reload_failed') unless Captive::wireless_reload();
		}
	}
}

if (($cgiparams{'ACTION'} // '') eq 'save-coupon-language') {
    my $language=$cgiparams{'translate'} // '';
    if ($language ne 'auto' && !exists $coupon_languages{$language}) {
        $errormessage=Captive::tr('invalid_company_language');
    } else {
        $settings{'translate'}=$language;
        delete $settings{'traslate'};
        Captive::write_settings($settingsfile, \%settings);
    }
}

if ($cgiparams{'ACTION'} eq "$Lang::tr{'Captive delete logo'}") {
	unlink $logo;
}

if ($cgiparams{'ACTION'} eq "$Lang::tr{'Captive generate coupons'}") {
    $errormessage = Captive::tr('invalid_count_duration')
        unless ($cgiparams{'COUNT'} // '') =~ /^(?:[1-9][0-9]?|100)\z/ && Captive::duration($cgiparams{'SESSION_TIME'});

	#check valid remark
	if ($cgiparams{'REMARK'} ne '' && !&validremark($cgiparams{'REMARK'})){
		$errormessage=Captive::tr('invalid_remark');
	}

	if (!$errormessage) {
		# Remember selected values
		foreach my $val (("COUNT", "REMARK")) {
			$settings{$val} = $cgiparams{$val};
		}
		Captive::write_settings($settingsfile, \%settings);

		&Captive::read_rows($coupons, \%couponhash) if (-e $coupons);
		my $now = time();

		# Expiry time in seconds
		my $expires = $cgiparams{'SESSION_TIME'};

		my $count = $settings{'COUNT'} || 1;
		while($count-- > 0) {
			# Generate a new code
			my $code = &gencode();

			# Check if the coupon code already exists
			foreach my $key (keys %couponhash) {
				if($couponhash{$key}[1] eq $code) {
					# Code already exists, so try again
					$code = "";
					$count++;
					last;
				}
			}

			next if ($code eq "");

			# Get a new key from hash
			my $key = Captive::next_key(\%couponhash);

			# Initialize all fields
			foreach my $i (0 .. 3) { $couponhash{$key}[$i] = ""; }

			$couponhash{$key}[0] = $now;
			$couponhash{$key}[1] = $code;
			$couponhash{$key}[2] = $expires;
			$couponhash{$key}[3] = $settings{'REMARK'};
		}

		# Save everything to disk
		&Captive::write_rows($coupons, \%couponhash);
	}
}

if ($cgiparams{'ACTION'} eq 'delete-coupon') {
	#deletes an already generated but unused voucher

	#read all generated vouchers
	&Captive::read_rows($coupons, \%couponhash) if (-e $coupons);
	foreach my $key (keys %couponhash) {
		if($cgiparams{'key'} eq $key){
			#write logenty with decoded remark
			my $rem=HTML::Entities::decode_entities($couponhash{$key}[3]);
			&General::log("Captive", "Administrator deleted unused coupon row $key");
			#delete line from hash
			delete $couponhash{$key};
			last;
		}
	}
	#write back hash
	&Captive::write_rows($coupons, \%couponhash);
}


if ($cgiparams{'ACTION'} eq 'add-client') {
    my $ip = $cgiparams{'IPADDR'} // '';
    my $mac = lc($cgiparams{'MACADDR'} // '');
    my $duration = $cgiparams{'SESSION_TIME'};
    my $note = $cgiparams{'NOTE'} // '';
    my $zone = Captive::zone($ip, \%settings, \%netsettings);
    if (!$zone || !Captive::valid_mac($mac) || !Captive::duration($duration) || !Captive::remark($note)) {
        $errormessage = Captive::tr('invalid_client');
    } else {
        Captive::read_rows($clients, \%clientshash);
        delete $clientshash{$_} for grep { $clientshash{$_}[0] eq $mac || $clientshash{$_}[1] eq $ip } keys %clientshash;
        $clientshash{Captive::next_key(\%clientshash)} = [$mac, $ip, time(), $duration, Captive::code(), $note];
        Captive::write_rows($clients, \%clientshash);
        $errormessage = Captive::tr('client_saved_reload_failed') unless Captive::reload();
        General::log('Captive', "Administrator authorized $ip on $zone");
    }
}

if ($cgiparams{'ACTION'} eq 'delete-client') {
	#delete voucher and connection in use

	#read all active clients
	&Captive::read_rows($clients, \%clientshash) if (-e $clients);
	foreach my $key (keys %clientshash) {
		if($cgiparams{'key'} eq $key){
			#prepare log entry with decoded remark
			my $rem=HTML::Entities::decode_entities($clientshash{$key}[5]);
			#write logentry
			&General::log("Captive", "Administrator revoked client $clientshash{$key}[1]");
			#delete line from hash
			delete $clientshash{$key};
			last;
		}
	}
	#write back hash
	&Captive::write_rows("$clients", \%clientshash);
	#reload firewallrules to kill connection of client
	$errormessage = Captive::tr('firewall_reload_failed') unless Captive::reload();
}

my $coupon_selected = $settings{'translate'} || $settings{'traslate'} || 'en';
$coupon_selected = 'en' unless $coupon_selected eq 'auto' || exists $coupon_languages{$coupon_selected};
my $coupon_language_options = '<option value="auto"' . ($coupon_selected eq 'auto' ? ' selected' : '') . '>' . Header::escape(Captive::tr('follow_gui')) . ' (' . Header::escape($coupon_languages{$mainsettings{'LANGUAGE'}} // $mainsettings{'LANGUAGE'} // 'English') . ')</option>';
for my $entry (@coupon_languages) {
    my ($code, $name) = @$entry;
    $coupon_language_options .= '<option value="' . Header::escape($code) . '"' . ($code eq $coupon_selected ? ' selected' : '') . '>' . Header::escape($name) . ' (' . Header::escape($code) . ')</option>';
}


my $logo_preview_src = -s $logo ? '/cgi-bin/captive/logo.cgi?v=' . time() . '-' . (-s $logo) : '';
my $logo_preview_style = $logo_preview_src ? '' : 'display: none;';
my $logo_preview_attr = $logo_preview_src ? ' src="' . Header::escape($logo_preview_src) . '"' : '';
my $logo_max_bytes = LOGO_MAX_BYTES;
&Header::showhttpheaders({'Cache-Control' => 'no-store'});
#open webpage, print header and open box
&Header::openpage($Lang::tr{'Captive'}, 1, '');
&Header::openbigbox();

# If an error message exists, show a box with the error message
if ($errormessage) {
	&Header::openbox('100%', 'left', $Lang::tr{'error messages'});
	print $errormessage;
	&Header::closebox();
}

# Prints the config box on the website
&Header::openbox('100%', 'left', $Lang::tr{'Captive config'});
print <<END
	<form method='post' action='$ENV{'SCRIPT_NAME'}' enctype="multipart/form-data">
        <input type='hidden' name='CSRF_TOKEN' value='$csrf_token'>\n
		<table width='100%' border="0">
END
;

#check which parameters have to be enabled (from settings file)
$checked{'ENABLE_GREEN'}{'off'} = '';
$checked{'ENABLE_GREEN'}{'on'} = '';
$checked{'ENABLE_GREEN'}{$settings{'ENABLE_GREEN'}} = "checked='checked'";

$checked{'ENABLE_BLUE'}{'off'} = '';
$checked{'ENABLE_BLUE'}{'on'} = '';
$checked{'ENABLE_BLUE'}{$settings{'ENABLE_BLUE'}} = "checked='checked'";

$checked{'UNLIMITED'}{'off'} = '';
$checked{'UNLIMITED'}{'on'} = '';
$checked{'UNLIMITED'}{$settings{'UNLIMITED'}} = "checked='checked'";

$selected{'AUTH'} = ();
$selected{'AUTH'}{'COUPON'} = "";
$selected{'AUTH'}{'TERMS'} = "";
$selected{'AUTH'}{$settings{'AUTH'}} = "selected";

if ($netsettings{'GREEN_DEV'}){
	print <<END;
		<tr>
			<td width='30%'>
				$Lang::tr{'Captive active on'}
				<font color='$Header::colourgreen'>$Lang::tr{'green'}</font>
			</td>
			<td>
				<input type='hidden' name='ENABLE_GREEN_PRESENT' value='1' />
				<input type='checkbox' name='ENABLE_GREEN' $checked{'ENABLE_GREEN'}{'on'} />
			</td>
		</tr>
END
}

if ($netsettings{'BLUE_DEV'}){
	print <<END;
		<tr>
			<td width='30%'>
				$Lang::tr{'Captive active on'}
				<font color='$Header::colourblue'>$Lang::tr{'blue'}</font>
			</td>
			<td>
				<input type='hidden' name='ENABLE_BLUE_PRESENT' value='1' />
				<input type='checkbox' name='ENABLE_BLUE' $checked{'ENABLE_BLUE'}{'on'} />
			</td>
		</tr>
END
}

print<<END
	<tr>
		<td>
			$Lang::tr{'Captive authentication'}
		</td>
		<td>
			<select name='AUTH'>
				<option value="TERMS"  $selected{'AUTH'}{'TERMS'} >$Lang::tr{'Captive terms'}</option>
				<option value="COUPON" $selected{'AUTH'}{'COUPON'}>$Lang::tr{'Captive coupon'}</option>
			</select>
		</td>
	</tr>
END
;

if ($settings{'AUTH'} eq 'TERMS') {
	$selected{'SESSION_TIME'} = ();
	foreach my $session_time (keys %session_times) {
		$selected{'SESSION_TIME'}{$session_time} = "";
	}
	$selected{'SESSION_TIME'}{$settings{'SESSION_TIME'}} = "selected";

	print <<END;
		<tr>
			<td>$Lang::tr{'Captive client session expiry time'}</td>
			<td>
				<select name="SESSION_TIME">
END

	foreach my $session_time (sort { $a <=> $b } keys %session_times) {
		print <<END;
					<option value="$session_time" $selected{'SESSION_TIME'}{$session_time}>
						$session_times{$session_time}
					</option>
END
	}

	print <<END;
				</select>
			</td>
		</tr>
END
}

print<<END;
	<tr>
		<td colspan="2">
			<br>
			<strong>$Lang::tr{'Captive branding'}</strong>
		</td>
	</tr>
	<tr>
		<td>
			$Lang::tr{'Captive title'}
		</td>
		<td>
			<input type='text' name='TITLE' value="@{[ &Header::escape($settings{'TITLE'}) ]}" size='40'>
		</td>
	</tr>
	<tr>
		<td>
			SSID
		</td>
		<td>
			<input type='text' name='ssid' value="@{[ &Header::escape($settings{'ssid'}) ]}" size='40'>
		</td>
	</tr>
	<tr>
		<td><label for="captive-company">@{[ Header::escape(Captive::tr('company')) ]}</label></td>
		<td><input type="text" id="captive-company" name="company" size="40" maxlength="200" value="@{[ &Header::escape($settings{'company'}) ]}"></td>
	</tr>
	<tr>
		<td>$Lang::tr{'Captive brand color'}</td>
		<td>
            <input type="color" name="COLOR" value="@{[ &Header::escape($settings{'COLOR'}) ]}">
		</td>
	</tr>
	<tr>
		<td>
			$Lang::tr{'Captive upload logo'}
		</td>
		<td>
			<style>
				.captive-file-input { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
				.captive-file-button { display: inline-block; padding: 3px 10px; border: 1px solid #999; border-radius: 2px; background: #f5f5f5; color: #111; cursor: pointer; }
				.captive-file-input:focus + .captive-file-button { outline: 2px solid #4a90e2; outline-offset: 2px; }
				.captive-file-name { margin-left: 8px; }
			</style>
			<input class="captive-file-input" type="file" name="logo" id="captive-logo-input" accept="image/png,image/jpeg"
                data-max-bytes="$logo_max_bytes"
                data-too-large="@{[ Header::escape(Captive::tr('logo_too_large')) ]}"
                data-invalid-type="@{[ Header::escape(Captive::tr('invalid_logo_upload')) ]}"
                data-preview-error="@{[ Header::escape(Captive::tr('logo_preview_error')) ]}"
                aria-describedby="captive-logo-help captive-logo-error">
			<label class="captive-file-button" for="captive-logo-input">@{[ Header::escape(Captive::tr('logo_choose_file')) ]}</label>
			<span class="captive-file-name" id="captive-logo-filename"
				data-empty="@{[ Header::escape(Captive::tr('logo_no_file_selected')) ]}">@{[ Header::escape(Captive::tr('logo_no_file_selected')) ]}</span>
            <div id="captive-logo-help" style="margin-top: 6px;">
                @{[ Header::escape(Captive::tr('logo_size_hint')) ]}
            </div>
            <div id="captive-logo-error" role="alert" style="color: #a40000; margin-top: 6px;"></div>
            <div id="captive-logo-preview" style="margin-top: 12px; $logo_preview_style">
                <div id="captive-logo-caption" style="margin-bottom: 6px;"
                    data-current="@{[ Header::escape(Captive::tr('logo_preview_current')) ]}"
                    data-selected="@{[ Header::escape(Captive::tr('logo_preview_new')) ]}">@{[ Header::escape(Captive::tr('logo_preview_current')) ]}</div>
                <img id="captive-logo-image"$logo_preview_attr data-current-src="@{[ Header::escape($logo_preview_src) ]}"
                    alt="@{[ Header::escape(Captive::tr('logo_preview_current')) ]}"
                    style="max-width: 320px; max-height: 180px; width: auto; height: auto; object-fit: contain; border: 1px solid #ccc; padding: 6px; background: #fff;">
            </div>
            <button type="button" id="captive-logo-clear" hidden style="margin-top: 8px;">@{[ Header::escape(Captive::tr('logo_clear_selection')) ]}</button>
            <script src="/captive/assets/logo-preview.js" defer></script>
		</td>
	</tr>
END

if (-e $logo) {
	print <<END;
		<tr>
			<td></td>
			<td>
				<input type='submit' name='ACTION' value="$Lang::tr{'Captive delete logo'}"/>
			</td>
		</tr>
END
}

my $terms = &getterms();
print <<END;
	<tr>

<td>@{[ Header::escape(Captive::tr('terms1')) ]}</td>

<td>

<textarea cols="50" rows="16" name="TERMS">@{[ &Header::escape($terms) ]}</textarea>

</td>

</tr>
	<tr>
		<td></td>
		<td align='right'>
			<input type='submit' name='ACTION' value="$Lang::tr{'save'}"/>
		</td>
	</tr>
	</table></form>
END

&Header::closebox();

&Header::openbox('100%', 'left', Captive::tr('coupon_language'));
print <<END;
<form method="post" action="$ENV{'SCRIPT_NAME'}">
<input type="hidden" name="CSRF_TOKEN" value="$csrf_token">
<input type="hidden" name="ACTION" value="save-coupon-language">
<label>@{[ Header::escape(Captive::tr('coupon_language')) ]}
<select name="translate">$coupon_language_options</select></label>
<input type="submit" value="$Lang::tr{'save'}">
</form>
END
&Header::closebox();

#if settings is set to use coupons, the coupon part has to be displayed
if ($settings{'AUTH'} eq 'COUPON') {
	&coupons();
}

# Add client
&add_client();

# Show active clients
&show_clients();

sub getterms() {
	my @ret;

	open(FILE, "<:raw", "/var/ipfire/captive/terms.txt");
	while(<FILE>) {
		push(@ret, $_);
	}
	close(FILE);

	return join('', @ret);
}

sub gencode { return Captive::code(); }

sub add_client() {
	&Header::openbox('100%', 'left', Captive::tr('add_client'));



	print <<END;
		<form method='post' action='$ENV{'SCRIPT_NAME'}'>
        <input type='hidden' name='CSRF_TOKEN' value='$csrf_token'>
		<table border='0' width='100%'>

			<tr>
				<td width='30%'>$Lang::tr{'mac address'}</td>
				<td>
					<input type='text'
						name='MACADDR'
						size='40'
						maxlength='17'
						required>
				</td>
				
			</tr>

			<tr>
				<td>$Lang::tr{'Captive ip'}</td>
				<td>
					<input type='text'
						name='IPADDR'
						size='40'
						required>
				</td>
			</tr>


			<tr>
				<td>$Lang::tr{'Captive vouchervalid'}</td>
				<td>
					<select name='SESSION_TIME'>
END

	foreach my $session_time (sort { $a <=> $b } keys %session_times) {
		print "<option value='$session_time'>$session_times{$session_time}</option>\n";
	}

	print <<END;
					</select>
				</td>
			</tr>



			<tr>
				<td>$Lang::tr{'remark'}</td>
				<td>
					<input type='text'
						name='NOTE'
						size='40'
						required>
				</td>
			</tr>

		</table>
		<div align="right">
		<input type='hidden'
			name='ACTION'
			value='add-client'>

		<input type='submit'
			value='@{[ Header::escape(Captive::tr('add_client')) ]}'>

		</form>
		</div>
END

	&Header::closebox();
}

sub coupons() {
	&Header::openbox('100%', 'left', $Lang::tr{'Captive generate coupons'});

	$selected{'SESSION_TIME'} = ();
	foreach my $session_time (keys %session_times) {
		$selected{'SESSION_TIME'}{$session_time} = "";
	}
	$selected{'SESSION_TIME'}{$settings{'SESSION_TIME'}} = "selected";

	print <<END;
		<form method='post' action='$ENV{'SCRIPT_NAME'}'>
        <input type='hidden' name='CSRF_TOKEN' value='$csrf_token'>
			<table border='0' width='100%'>
				<tr>
					<td width='30%'>
						$Lang::tr{'Captive vouchervalid'}
					</td>
					<td width='70%'>
						<select name="SESSION_TIME">
END

	foreach my $session_time (sort { $a <=> $b } keys %session_times) {
		print <<END;
							<option value="$session_time" $selected{'SESSION_TIME'}{$session_time}>
								$session_times{$session_time}
							</option>
END
	}

	print <<END;
						</select>
					</td>
				</tr>
				<tr>
					<td>$Lang::tr{'remark'}</td>
					<td>
						<input type='text' name='REMARK' size=40>
					</td>
				</tr>
				<tr>
					<td>$Lang::tr{'Captive generated coupon no'}</td>
					<td>
						<select name="COUNT">
							<option value="1">1</option>
							<option value="2">2</option>
							<option value="3">3</option>
							<option value="4">4</option>
							<option value="5">5</option>
							<option value="6">6</option>
							<option value="7">7</option>
							<option value="8">8</option>
							<option value="9">9</option>
							<option value="10">10</option>
							<option value="20">20</option>
							<option value="50">50</option>
							<option value="100">100</option>
						</select>
					</td>
				</tr>
			</table>

			<div align="right">
				<input type="submit" name="ACTION" value="$Lang::tr{'Captive generate coupons'}">
			</div>
		</form>
END

	&Header::closebox();

	# Show all coupons if exist
	if (! -z $coupons) {
		&show_coupons();
	}
}

sub show_coupons() {
	&Captive::read_rows($coupons, \%couponhash) if (-e $coupons);

	#if there are already generated but unsused coupons, print a table
	&Header::openbox('100%', 'left', $Lang::tr{'Captive issued coupons'});

	print <<END;
		<table class='tbl' border='0'>
			<tr>
				<th align='center' width='15%'>
					$Lang::tr{'Captive coupon'}
				</th>
				<th align='center' width='15%'>$Lang::tr{'Captive expiry time'}</th>
				<th align='center' width='65%'>$Lang::tr{'remark'}</th>
				<th align='center' width='5%'>$Lang::tr{'delete'}</th>
			</tr>
END

	foreach my $key (keys %couponhash) {
		my $expirytime = $Lang::tr{'Captive nolimit'};
		if ($couponhash{$key}[2] > 0) {
			$expirytime = &General::format_time($couponhash{$key}[2]);
		}

		if ($count++ % 2) {
			$col="bgcolor='$color{'color20'}'";
		} else {
			$col="bgcolor='$color{'color22'}'";
		}

		print <<END;
			<tr>
				<td $col align="center">
					<b>@{[ &Header::escape($couponhash{$key}[1]) ]}</b>
				</td>
				<td $col align="center">
					$expirytime
				</td>
				<td $col align="center">
					$couponhash{$key}[3]
				</td>
				<td $col align="center">
					<form method='post'>
        <input type='hidden' name='CSRF_TOKEN' value='$csrf_token'>
						<input type='image' src='/images/delete.gif' align='middle' alt='$Lang::tr{'delete'}' title='$Lang::tr{'delete'}' />
						<input type='hidden' name='ACTION' value='delete-coupon' />
						<input type='hidden' name='key' value='$key' />
					</form>
				</td>
			</tr>
END
	}

	print "</table>";

	# Keep the export action visibly separated from the coupon table.
	print <<END;
		<div class="captive-coupon-export" style="margin-top: 18px; padding: 4px 0; text-align: right;">
			<form method="GET" action="/CaptivePortal/export.cgi" style="display: inline-block; margin: 0;">
				<input type="submit" value="$Lang::tr{'Captive export coupons'}">
			</form>
		</div>
END

	&Header::closebox();
}

sub show_clients() {
	# if there are active clients which use coupons show table
	return if ( -z $clients || ! -f $clients );

	my $count=0;
	my $col;

	&Header::openbox('100%', 'left', $Lang::tr{'Captive clients'});

	print <<END;
		<table class='tbl' width='100%'>
			<tr>
				<th align='center' width='15%'>$Lang::tr{'Captive coupon'}</th>
				<th align='center' width='15%'>$Lang::tr{'Captive activated'}</th>
				<th align='center' width='15%'>$Lang::tr{'Captive expiry time'}</th>
				<th align='center' width='10%'>$Lang::tr{'Captive mac'}</th>
				<th align='center' width='43%'>$Lang::tr{'remark'}</th>
				<th align='center' width='5%'>$Lang::tr{'delete'}</th>
			</tr>
END

	&Captive::read_rows($clients, \%clientshash) if (-e $clients);
	foreach my $key (sort {$clientshash{$a}[2] <=> $clientshash{$b}[2]} keys %clientshash) {
		#calculate time from clientshash (starttime)
		my $starttime = sub{sprintf '%02d.%02d.%04d %02d:%02d', $_[3], $_[4]+1, $_[5]+1900, $_[2], $_[1]  }->(localtime($clientshash{$key}[2]));

		#calculate endtime from clientshash
		my $endtime;
		if ($clientshash{$key}[3] eq '0'){
			$endtime=$Lang::tr{'Captive nolimit'};
		} else {
			$endtime = sub{sprintf '%02d.%02d.%04d %02d:%02d', $_[3], $_[4]+1, $_[5]+1900, $_[2], $_[1]  }->(localtime($clientshash{$key}[2]+$clientshash{$key}[3]));
		}

		if ($count++ % 2) {
			$col="bgcolor='$color{'color20'}'";
		} else {
			$col="bgcolor='$color{'color22'}'";
		}

		my $coupon = ($clientshash{$key}[4] eq "TERMS") ? $Lang::tr{'Captive terms short'} : $clientshash{$key}[4];

		print <<END;
			<tr>
				<td $col align="center"><b>@{[ &Header::escape($coupon) ]}</b></td>
				<td $col align="center">$starttime</td>
				<td $col align="center">$endtime</td>
				<td $col align="center">@{[ &Header::escape($clientshash{$key}[0]) ]}</td>
				<td $col align="center">@{[ &Header::escape($clientshash{$key}[5]) ]}</td>
				<td $col align="center">
					<form method='post'>
        <input type='hidden' name='CSRF_TOKEN' value='$csrf_token'>
						<input type='image' src='/images/delete.gif' align='middle' alt='$Lang::tr{'delete'}' title='$Lang::tr{'delete'}' />
						<input type='hidden' name='ACTION' value='delete-client' />
						<input type='hidden' name='key' value='$key' />
					</form>
				</td>
			</tr>
END
	}

	print "</table>";

	&Header::closebox();
}

sub validremark { return Captive::remark($_[0]); }

sub generate_pdf {
    require '/var/ipfire/captive-pdf.pl';
    my %rows;
    Captive::read_rows($coupons, \%rows);
    close($state_lock); # Render the snapshot without blocking authorization writers.
    my ($language,$words)=Captive::coupon_words($settings{'translate'}||$settings{'traslate'}||'en',$mainsettings{'LANGUAGE'});
    return CaptivePDF::generate(
        coupons => \%rows, title => $words->{pdf_title},
        company => $settings{'company'} // '', ssid => $settings{'ssid'} // '',
        labels => {company => $words->{company_prefix}, ssid => $words->{ssid_prefix},
                   validity => $words->{valid_until}, remark => $words->{note_prefix}, empty => $words->{no_coupons}},
        duration => sub { Captive::coupon_duration($_[0],$words) },
    );
}

&Header::closebigbox();
&Header::closepage();
