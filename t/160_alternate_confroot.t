# Check that we can do all operations using a per-user $PG_CLUSTER_CONF_ROOT 

use strict; 

use lib 't';
use TestLib;

my $version = $MAJORS[0];

use Test::More tests => 30;

# prepare nobody-owned root dir for $PG_CLUSTER_CONF_ROOT
my $rootdir=`su -s /bin/sh -c 'mktemp -d' nobody`;
chomp $rootdir;
($rootdir) = $rootdir =~ m!^([a-zA-Z0-9._/]+)$!; # untaint
$ENV{'PG_CLUSTER_CONF_ROOT'} = "$rootdir/etc";

is ((exec_as 'nobody', "pg_createcluster $version test -d $rootdir/data/test -l $rootdir/test.log --start"), 0);

is_program_out 'nobody', 'env -u PG_CLUSTER_CONF_ROOT pg_lsclusters -h', 0, '';
like_program_out 'nobody', "pg_lsclusters -h", 0,
    qr!^$version\s+test.*online\s+nobody\s+$rootdir/data/test\s+$rootdir/test.log$!;

like_program_out 'nobody', "psql -Atl", 0, qr/template1.*UTF8/;

# pg_upgradecluster
if ($MAJORS[0] ne $MAJORS[-1]) {
    my $outref;
    is ((exec_as 'nobody', "pg_upgradecluster --logfile $rootdir/testupgr.log -v $MAJORS[-1] $version test $rootdir/data/testupgr", $outref, 0), 0);
    like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
    like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

    like_program_out 'nobody', 'pg_lsclusters -h', 0,
        qr!^$version\s+test.*down.*\n^$MAJORS[-1]\s+test.*online\s+nobody\s+$rootdir/data/testupgr\s+$rootdir/testupgr.log$!m;

    # clean up
    is_program_out 'nobody', "pg_dropcluster $version test", 0, '';
    is_program_out 'nobody', "pg_dropcluster $MAJORS[-1] test --stop", 0, '';
} else {
    pass 'Only one major version installed, skipping pg_upgradecluster tests';
    for (my $i = 0; $i < 6; ++$i) { pass '...'; }

    is_program_out 'nobody', "pg_dropcluster $version test --stop", 0, '';
}

# pg_dropcluster
is_program_out 'nobody', "pg_lsclusters -h", 0, '';

ok_dir "$rootdir/data", [], 'No files in root/data left behind';
ok_dir "$rootdir", ['etc', 'data'], 'No cruft in root dir left behind';

system "rm -rf $rootdir";

delete $ENV{'PG_CLUSTER_CONF_ROOT'};
check_clean;

# vim: filetype=perl
