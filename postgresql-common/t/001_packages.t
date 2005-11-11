#!/usr/bin/perl -w
# Check that the necessary packages are installed; we want all major servers,
# no contrib for 7.4, and contrib for 8.0

use strict;

use lib 't';
use TestLib;

use Test::More tests => 2 + ($#MAJORS+1);

foreach my $v (@MAJORS) {
    ok ((deb_installed "postgresql-$v"), "postgresql-$v installed");
}

ok ((!deb_installed 'postgresql-contrib-7.4'), 'postgresql-contrib-7.4 not installed');
ok ((deb_installed 'postgresql-contrib-8.0'), 'postgresql-contrib-8.0 installed');

# vim: filetype=perl
