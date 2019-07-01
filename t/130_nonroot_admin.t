# Check that cluster administration works as non-root if the invoker has
# sufficient permissions on directories.

use strict; 

use lib 't';
use TestLib;

my $version = $MAJORS[-1];
my $oldversion = $MAJORS[0];

use Test::More tests => 22;
use PgCommon;

my $testuser = 'postgres';

# pg_createcluster and pg_ctlcluster
is ((exec_as $testuser, "pg_createcluster $version main --start"), 0,
    "pg_createcluster succeeds as user $testuser with appropriate owner permissions");

like_program_out $testuser, 'pg_lsclusters -h', 0, qr/^$version\s+main.*online/m;
like_program_out 'postgres', 'psql -Atl', 0, qr/template1.*UTF8/;

# pg_dropcluster
is ((exec_as $testuser, "pg_dropcluster $version main --stop"), 0,
    "pg_dropcluster succeeds as user $testuser with appropriate directory owner permissions");

# pg_upgradecluster
SKIP: {
    skip 'Only one major version installed, skipping pg_upgradecluster tests', 8 if ($oldversion eq $version);

    is ((exec_as $testuser, "pg_createcluster $oldversion main --start"), 0,
        "pg_createcluster succeeds as user $testuser with appropriate group permissions");
    my $outref;
    is ((exec_as $testuser, "pg_upgradecluster -v $version $oldversion main", $outref, 0), 0, 
        "pg_upgradecluster succeeds as user $testuser");
    like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
    like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

    like_program_out $testuser, 'pg_lsclusters -h', 0,
        qr/^$oldversion\s+main.*down.*\n^$version\s+main.*online/m;

    # clean up
    is ((exec_as $testuser, "pg_dropcluster $oldversion main"), 0);
    is ((exec_as $testuser, "pg_dropcluster $version main --stop"), 0);
}

check_clean;

# vim: filetype=perl
