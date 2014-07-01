# Check pg_config output

use strict;

use lib 't';
use TestLib;

use Test::More tests => 8 * ($#MAJORS+2);

use lib '/usr/share/postgresql-common';
use PgCommon;

my $multiarch = '';
unless ($PgCommon::rpm) {
    $multiarch = `dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null`;
    chomp $multiarch;
}
note "Multiarch is " . ($multiarch ? 'enabled' : 'disabled');

# check version specific output
my $version;
foreach $version (@MAJORS) {
    if ($version < '8.2') {
        pass "Skipping known-broken pg_config check for version $version";
        for (my $i = 0; $i < 7; ++$i) { pass '...'; }
        next;
    }
    is_program_out 'postgres', "$PgCommon::binroot$version/bin/pg_config --pgxs", 0, 
        "$PgCommon::binroot$version/lib/pgxs/src/makefiles/pgxs.mk\n";
    my $libdir = "/usr/lib" . ($version >= 9.3 and $multiarch ? "/$multiarch" : "") . "\n";
    $libdir = "$PgCommon::binroot$version/lib\n" if ($PgCommon::rpm);
    is_program_out 'postgres', "$PgCommon::binroot$version/bin/pg_config --libdir", 0, 
        $libdir;
    is_program_out 'postgres', "$PgCommon::binroot$version/bin/pg_config --pkglibdir", 0, 
        "$PgCommon::binroot$version/lib\n";
    is_program_out 'postgres', "$PgCommon::binroot$version/bin/pg_config --bindir", 0, 
        "$PgCommon::binroot$version/bin\n";
}

# check client-side output (should behave like latest server-side one)
$version = $ALL_MAJORS[-1];
is_program_out 'postgres', "pg_config --pgxs", 0, 
    "$PgCommon::binroot$version/lib/pgxs/src/makefiles/pgxs.mk\n";
my $libdir = "/usr/lib" . ($version >= 9.3 and $multiarch ? "/$multiarch" : "") . "\n";
$libdir = "$PgCommon::binroot$version/lib\n" if ($PgCommon::rpm);
is_program_out 'postgres', "pg_config --libdir", 0, 
    $libdir;
is_program_out 'postgres', "pg_config --pkglibdir", 0, 
    "$PgCommon::binroot$version/lib\n";
is_program_out 'postgres', "pg_config --bindir", 0, 
    "$PgCommon::binroot$version/bin\n";
