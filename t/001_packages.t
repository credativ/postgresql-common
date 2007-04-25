# Check that the necessary packages are installed; we want all major servers,
# no contrib for 7.4, and contrib for 8.0

use strict;

use lib 't';
use TestLib;
use POSIX qw/setlocale LC_ALL/;

use Test::More tests => 5 + ($#MAJORS+1)*3;

foreach my $v (@MAJORS) {
    ok ((deb_installed "postgresql-$v"), "postgresql-$v installed");
    ok ((deb_installed "postgresql-plpython-$v"), "postgresql-plpython-$v installed");
    ok ((deb_installed "postgresql-plperl-$v"), "postgresql-plperl-$v installed");
}

ok ((!deb_installed 'postgresql-contrib-7.4'), 'postgresql-contrib-7.4 not installed');
if (deb_installed 'postgresql-8.0') {
    ok ((deb_installed 'postgresql-contrib-8.0'), 'postgresql-contrib-8.0 installed');
} else {
    pass 'postgresql-8.0 not installed, skipping check for postgresql-contrib-8.0';
}

ok ((deb_installed 'procps'), 'procps installed');

# check installed locales to fail tests early if they are missing
ok (setlocale (LC_ALL, "ru_RU"), 'locale ru_RU exists');
ok (setlocale (LC_ALL, "ru_RU.UTF-8"), 'locale ru_RU.UTF-8 exists');

# vim: filetype=perl
