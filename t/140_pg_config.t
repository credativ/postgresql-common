# Check pg_config output

use strict;

use lib 't';
use TestLib;
use PgCommon;
use Test::More tests => 14 * @MAJORS + ($PgCommon::rpm ? 1 : 2) * 12;

my $multiarch = '';
unless ($PgCommon::rpm) {
    $multiarch = `dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null`;
    chomp $multiarch;
}
note "Multiarch is " . ($multiarch ? 'enabled' : 'disabled');

my $version;
foreach $version (@MAJORS) {
    note "checking version specific output for $version";
    if ($version < '8.2') {
        pass "Skipping known-broken pg_config check for version $version";
        for (my $i = 0; $i < 13; ++$i) { pass '...'; }
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
    # mkdir should be in /bin on Debian. If /bin was linked to /usr/bin at build time, usrmerge was installed
    SKIP: {
        skip 'MKDIR_P not present before 9.0', 2 if ($version < 9.0);
        my $mkdir_path = $PgCommon::rpm ? '/usr/bin' : '/bin';
        is_program_out 'postgres', "grep ^MKDIR_P $PgCommon::binroot$version/lib/pgxs/src/Makefile.global", 0, 
            "MKDIR_P = $mkdir_path/mkdir -p\n";
    }
    SKIP: {
        skip 'build path not canonicalized on RedHat', 4 if ($PgCommon::rpm);
        my $pkgversion = `dpkg-query -f '\${Version}' -W postgresql-server-dev-$version`;
        # check that we correctly canonicalized the build paths
        SKIP: {
            skip 'abs_top_builddir introduced in 9.5', 2 if ($version < 9.5);
            skip 'abs_top_builddir not patched in Debian (old)stable', 2 if ($version < 10 and $pkgversion !~ /pgdg/);
            is_program_out 'postgres', "grep ^abs_top_builddir $PgCommon::binroot$version/lib/pgxs/src/Makefile.global", 0,
                "abs_top_builddir = /build/postgresql-$version/build\n";
        }
        SKIP: {
            skip 'abs_top_srcdir not patched before 9.3', 2 if ($version < 9.3);
            skip 'abs_top_srcdir not patched in Debian (old)stable', 2 if ($version < 10 and $pkgversion !~ /pgdg/);
            is_program_out 'postgres', "grep ^abs_top_srcdir $PgCommon::binroot$version/lib/pgxs/src/Makefile.global", 0,
                "abs_top_srcdir = /build/postgresql-$version/build/..\n";
        }
    }
}

my @pg_configs = $PgCommon::rpm ? qw(pg_config) : qw(pg_config pg_config.libpq-dev);
for my $pg_config (@pg_configs) {
    if ($pg_config eq 'pg_config' or $PgCommon::rpm) { # pg_config should point at newest installed postgresql-server-dev-$version
        $version = $ALL_MAJORS[-1];
    } else { # pg_config.libpq-dev should point at postgresql-server-dev-$(version of libpq-dev)
        my $libpqdev_version = `dpkg-query --showformat '\${Version}' --show libpq-dev`;
        $libpqdev_version =~ /^([89].\d|1.)/ or die "could not determine libpq-dev version";
        $version = $1;
    }
    note "checking $pg_config output (should behave like version $version)";

    SKIP: {
        my $pgc = "$PgCommon::binroot$version/bin/pg_config";
        skip "$pgc not installed, can't check full $pg_config output", 2 unless (-x $pgc);
        my $full_output = `$pgc`;
        is_program_out 'postgres', "$pg_config", 0, $full_output;
    }
    like_program_out 'postgres', "$pg_config --help", 0, qr/--includedir-server/;
    is_program_out 'postgres', "$pg_config --pgxs", 0,
        "$PgCommon::binroot$version/lib/pgxs/src/makefiles/pgxs.mk\n";
    my $libdir = "/usr/lib" . ($version >= 9.3 and $multiarch ? "/$multiarch" : "") . "\n";
    $libdir = "$PgCommon::binroot$version/lib\n" if ($PgCommon::rpm);
    is_program_out 'postgres', "$pg_config --libdir", 0,
        $libdir;
    is_program_out 'postgres', "$pg_config --pkglibdir", 0,
        "$PgCommon::binroot$version/lib\n";
    is_program_out 'postgres', "$pg_config --bindir", 0,
        "$PgCommon::binroot$version/bin\n";
}
