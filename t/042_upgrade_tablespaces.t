# Check upgrading of tablespaces; right now this is not supported, so we just
# check that no damage is done.

use strict; 

use File::Temp qw/tempdir/;

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => ($#MAJORS == 0) ? 1 : 14;

if ($#MAJORS == 0) {
    pass 'only one major version installed, skipping upgrade tests';
    exit 0;
}

# create cluster
ok ((system "pg_createcluster $MAJORS[0] upgr --start >/dev/null") == 0,
    "pg_createcluster $MAJORS[0] upgr");

# create a tablespace
my $tdir = tempdir (CLEANUP => 1);
my ($p_uid, $p_gid) = (getpwnam 'postgres')[2,3];
chown $p_uid, $p_gid, $tdir;

is ((exec_as 'postgres', "psql template1 -c \"CREATE TABLESPACE myts LOCATION '$tdir'\""),
    0, "creating tablespace in $tdir");

# attempt to upgrade

my $outref;
exec_as 0, "(pg_upgradecluster $MAJORS[0] upgr | sed -e 's/^/STDOUT: /')", $outref, 0;
my @err = grep (!/^STDOUT: /, split (/\n/, $$outref));
ok ($err[0] =~ /tablespaces.*not supported/, 'error message about unsupported tablespaces');

# clean up
is ((system "pg_dropcluster $MAJORS[0] upgr --stop"), 0, "pg_dropcluster $MAJORS[0] upgr");
check_clean;

# vim: filetype=perl
