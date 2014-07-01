# Check that the necessary packages are installed

use strict;

use lib 't';
use TestLib;
use POSIX qw/setlocale LC_ALL LC_MESSAGES/;

use Test::More tests => $PgCommon::rpm ? (8*@MAJORS) : (12 + 7*@MAJORS);

note "PostgreSQL versions installed: @MAJORS\n";

if ($PgCommon::rpm) {
    foreach my $v (@MAJORS) {
        my $vv = $v;
        $vv =~ s/\.//;

        ok ((rpm_installed "postgresql$vv"),          "postgresql$vv installed");
        ok ((rpm_installed "postgresql$vv-libs"),     "postgresql$vv-libs installed");
        ok ((rpm_installed "postgresql$vv-server"),   "postgresql$vv-server installed");
        ok ((rpm_installed "postgresql$vv-contrib"),  "postgresql$vv-contrib installed");
        ok ((rpm_installed "postgresql$vv-plperl"),   "postgresql$vv-plperl installed");
        ok ((rpm_installed "postgresql$vv-plpython"), "postgresql$vv-plpython installed");
        ok ((rpm_installed "postgresql$vv-pltcl"),    "postgresql$vv-pltcl installed");
        ok ((rpm_installed "postgresql$vv-devel"),    "postgresql$vv-devel installed");
    }
    exit;
}

foreach my $v (@MAJORS) {
    ok ((deb_installed "postgresql-$v"), "postgresql-$v installed");
    ok ((deb_installed "postgresql-plpython-$v"), "postgresql-plpython-$v installed");
    if ($v >= '9.1') {
	ok ((deb_installed "postgresql-plpython3-$v"), "postgresql-plpython3-$v installed");
    } else {
	pass "no Python 3 package for version $v";
    }
    ok ((deb_installed "postgresql-plperl-$v"), "postgresql-plperl-$v installed");
    ok ((deb_installed "postgresql-pltcl-$v"), "postgresql-pltcl-$v installed");
    ok ((deb_installed "postgresql-server-dev-$v"), "postgresql-server-dev-$v installed");
    ok ((deb_installed "postgresql-contrib-$v"), "postgresql-contrib-$v installed");
}

ok ((deb_installed 'libecpg-dev'), 'libecpg-dev installed');
ok ((deb_installed 'logrotate'), 'logrotate installed');
ok ((deb_installed 'procps'), 'procps installed');
ok ((deb_installed 'netcat-openbsd'), 'netcat-openbsd installed');

ok ((deb_installed 'hunspell-en-us'), 'hunspell-en-us installed');

# check installed locales to fail tests early if they are missing
ok ((setlocale(LC_MESSAGES, '') =~ /utf8|UTF-8/), 'system has a default UTF-8 locale');
ok (setlocale (LC_ALL, "ru_RU"), 'locale ru_RU exists');
ok (setlocale (LC_ALL, "ru_RU.UTF-8"), 'locale ru_RU.UTF-8 exists');

my $key_file = '/etc/ssl/private/ssl-cert-snakeoil.key';
my $pem_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem';
ok ((getgrnam('ssl-cert'))[3] =~ /postgres/, 
    'user postgres in the UNIX group ssl-cert');
ok (-e $key_file, "$key_file exists");
is (exec_as ('postgres', "cat $key_file > /dev/null"), 0, "$key_file is readable for postgres");
ok (-e $pem_file, "$pem_file exists");

# vim: filetype=perl
