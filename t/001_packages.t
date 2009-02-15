# Check that the necessary packages are installed

use strict;

use lib 't';
use TestLib;
use POSIX qw/setlocale LC_ALL/;

use Test::More tests => 4 + ($#MAJORS+1)*4;

foreach my $v (@MAJORS) {
    ok ((deb_installed "postgresql-$v"), "postgresql-$v installed");
    ok ((deb_installed "postgresql-plpython-$v"), "postgresql-plpython-$v installed");
    ok ((deb_installed "postgresql-plperl-$v"), "postgresql-plperl-$v installed");
    ok ((deb_installed "postgresql-pltcl-$v"), "postgresql-pltcl-$v installed");
}

ok ((deb_installed 'procps'), 'procps installed');

ok ((deb_installed 'hunspell-en-us'), 'hunspell-en-us installed');

# check installed locales to fail tests early if they are missing
ok (setlocale (LC_ALL, "ru_RU"), 'locale ru_RU exists');
ok (setlocale (LC_ALL, "ru_RU.UTF-8"), 'locale ru_RU.UTF-8 exists');

# vim: filetype=perl
