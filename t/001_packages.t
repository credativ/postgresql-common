# Check that the necessary packages are installed

use strict;

use lib 't';
use TestLib;
use POSIX qw/setlocale LC_ALL LC_MESSAGES/;

use Test::More tests => 7 + ($#MAJORS+1)*6;

foreach my $v (@MAJORS) {
    ok ((deb_installed "postgresql-$v"), "postgresql-$v installed");
    ok ((deb_installed "postgresql-plpython-$v"), "postgresql-plpython-$v installed");
    if ($v ge '9.1') {
	ok ((deb_installed "postgresql-plpython3-$v"), "postgresql-plpython3-$v installed");
    } else {
	pass "no Python 3 package for version $v";
    }
    ok ((deb_installed "postgresql-plperl-$v"), "postgresql-plperl-$v installed");
    ok ((deb_installed "postgresql-pltcl-$v"), "postgresql-pltcl-$v installed");
    ok ((deb_installed "postgresql-server-dev-$v"), "postgresql-server-dev-$v installed");
}

ok ((deb_installed 'libecpg-dev'), 'libecpg-dev installed');
ok ((deb_installed 'procps'), 'procps installed');

ok ((deb_installed 'hunspell-en-us'), 'hunspell-en-us installed');

# check installed locales to fail tests early if they are missing
ok ((setlocale(LC_MESSAGES, '') =~ /utf8|UTF-8/), 'system has a default UTF-8 locale');
ok (setlocale (LC_ALL, "ru_RU"), 'locale ru_RU exists');
ok (setlocale (LC_ALL, "ru_RU.UTF-8"), 'locale ru_RU.UTF-8 exists');

ok ((getgrnam('ssl-cert'))[3] =~ /postgres/, 
    'user postgres in the UNIX group ssl-cert');

# vim: filetype=perl
