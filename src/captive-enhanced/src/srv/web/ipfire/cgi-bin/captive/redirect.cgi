#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A linux based firewall                                         #
# Copyright (C) 2016 Alexander Marx alexander.marx@ipfire.org                 #
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
use warnings;
use URI::Escape qw(uri_escape);
require '/var/ipfire/general-functions.pl';
require '/var/ipfire/captive-lib.pl';
my (%settings, %net);
General::readhash('/var/ipfire/captive/settings', \%settings);
General::readhash('/var/ipfire/ethernet/settings', \%net);
my $zone = Captive::zone($ENV{'REMOTE_ADDR'} // '', \%settings, \%net);
Captive::fail('403 Forbidden', 'network_disabled') unless $zone;
my $host = $ENV{'HTTP_HOST'} // $ENV{'SERVER_NAME'} // '';
my $url = Captive::safe_url('http://' . $host . ($ENV{'REQUEST_URI'} // '/'));
my $target = $net{"${zone}_ADDRESS"};
print "Status: 302 Found\r\nCache-Control: no-store\r\nLocation: http://$target:1013/cgi-bin/index.cgi?redirect=" . uri_escape($url) . "\r\n\r\n";
