# Check pg_buildext and that our debhelper integration works

use strict;

use lib 't';
use TestLib;
use PgCommon;
use Test::More;

if ($PgCommon::rpm) {
    pass 'No pg_buildext tests on RedHat';
    done_testing();
    exit;
}

# when invoked from the postgresql-NN package tests, postgresql-server-dev-all is not installed
if (! -x '/usr/bin/dh_make_pgxs') {
    pass "Skipping pg_buildext tests, /usr/bin/dh_make_pgxs is not installed";
    done_testing();
    exit;
}

my $arch = `dpkg-architecture -qDEB_HOST_ARCH`;
chomp $arch;

if ($ENV{PG_VERSIONS}) {
    note "PG_VERSIONS=$ENV{PG_VERSIONS}";
    $ENV{PG_SUPPORTED_VERSIONS} = join ' ', (grep { $_ >= 9.1 } split /\s+/, $ENV{PG_VERSIONS});
    unless ($ENV{PG_SUPPORTED_VERSIONS}) {
        ok 1, 'No versions with extension support to test';
        done_testing();
        exit;
    }
    note "PG_SUPPORTED_VERSIONS=$ENV{PG_SUPPORTED_VERSIONS}";
}
my @versions = split /\s+/, `/usr/share/postgresql-common/supported-versions`;

# prepare build environment
chdir 't/foo';
chmod 0777, '.', 'foo-123';
umask 0022;

program_ok 0, 'make clean';
program_ok 'nobody', 'make tar';
program_ok 'nobody', 'cd foo-123 && echo y | EDITOR=true dh_make_pgxs';

note "testing 'dh --with pgxs'";
program_ok 'nobody', 'cd foo-123 && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc';

foreach my $ver (@versions) {
    my $deb = "postgresql-$ver-foo_123-1_$arch.deb";
    ok (-f $deb, "$deb was built");
    SKIP: {
        my $have_extension_destdir = `grep extension_destdir /usr/share/postgresql/$ver/postgresql.conf.sample`;
        skip "No in-tree installcheck on PG $ver (missing extension_destdir)", 2 unless ($have_extension_destdir);
        like_program_out 'nobody', "cd foo-123 && PG_SUPPORTED_VERSIONS=$ver dh_pgxs_test",
            0, qr/PostgreSQL $ver installcheck.*test foo * \.\.\. ok/s;
    }
    program_ok 0, "dpkg -i $deb";
    like_program_out 'nobody', "cd foo-123 && pg_buildext installcheck",
        0, qr/PostgreSQL $ver installcheck.*test foo * \.\.\. ok/s;
    like_program_out 'nobody', "cd foo-123 && echo 'SELECT 3*41, version()' | pg_buildext psql", 0, qr/123.*PostgreSQL $ver/;
    like_program_out 'nobody', "cd foo-123 && echo 'echo --\$PGVERSION--' | pg_buildext virtualenv", 0, qr/--$ver--/;
    program_ok 0, "dpkg -r postgresql-$ver-foo";
}

note "testing 'dh --with pgxs_loop'";
system "rm -f postgresql-*.deb";

program_ok 'nobody', 'sed -i -e s/pgxs/pgxs_loop/ foo-123/debian/rules';
program_ok 'nobody', 'cd foo-123 && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc';

foreach my $ver (@versions) {
    my $deb = "postgresql-$ver-foo_123-1_$arch.deb";
    ok (-f $deb, "$deb was built");
}

program_ok 'nobody', 'make clean';

done_testing();

# vim: filetype=perl
