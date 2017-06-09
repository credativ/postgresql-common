# Check properties of the installed packages/binaries

use strict;

use lib 't';
use TestLib;
use PgCommon qw/$binroot/;

use Test::More tests => (@MAJORS) * 4;

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

# vim: filetype=perl
