#!/usr/bin/perl -w
# Check that the necessary packages are installed; we want 7.4 and 8.0 servers
# and contrib for 8.0

use strict;
use Test::More tests => 4;

sub deb_installed {
    open (DPKG, '-|', 'dpkg', '-s', $_[0]) or die "call dpkg: $!";
    while (<DPKG>) {
	return 1 if /^Version:/;
    }

    return 0;
}

ok ((deb_installed 'postgresql-7.4'), 'postgresql-7.4 installed');
ok ((!deb_installed 'postgresql-contrib-7.4'), 'postgresql-7.4 not installed');
ok ((deb_installed 'postgresql-8.0'), 'postgresql-8.0 installed');
ok ((deb_installed 'postgresql-contrib-8.0'), 'postgresql-contrib-8.0 installed');

# vim: filetype=perl
