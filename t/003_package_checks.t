# Check properties of the installed packages/binaries

use strict;

use lib 't';
use TestLib;
use PgCommon qw/$binroot/;

use Test::More tests => (@MAJORS) * 4 + 1;

# Debian/Ubuntu packages are linked against libedit. If your psql binaries are
# linked against libreadline, set PG_READLINE=1 when running this testsuite.
$ENV{PG_READLINE} = 1 if ($PgCommon::rpm);
my ($want_lib, $avoid_lib) = $ENV{PG_READLINE} ? qw(libreadline libedit) : qw(libedit libreadline);

foreach my $v (@MAJORS) {
    like_program_out (0, "ldd $binroot$v/bin/psql", 0, qr/$want_lib\.so\./,
	"psql is linked against $want_lib");
    unlike_program_out (0, "ldd $binroot$v/bin/psql", 0, qr/$avoid_lib\.so\./,
	"psql is not linked against $avoid_lib");
}

my $lrversion = package_version ('logrotate');
my $is_logrotate_38 = version_ge ($lrversion, '3.8');
note "logrotate version $lrversion is " . ($is_logrotate_38 ? 'greater' : 'smaller') . " than 3.8";
my $f = "/etc/logrotate.d/postgresql-common";
open F, $f;
undef $/; # slurp mode
my $t = <F>;
close F;
if ($is_logrotate_38) {
    like $t, qr/\bsu /, "$f contains su directive";
} else {
    unlike $t, qr/\bsu /, "$f does not contain su directive";
}

# vim: filetype=perl
