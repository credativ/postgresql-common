# Test cluster upgrade with a custom data directory and custom log file.

use strict; 

use lib 't';
use TestLib;
use PgCommon;
use Test::More tests => (@MAJORS == 1) ? 1 : 28;

if (@MAJORS == 1) {
    pass 'only one major version installed, skipping upgrade tests';
    exit 0;
}

ok ((system "pg_createcluster --start --datadir /tmp/postgresql-test -l /tmp/postgresql-test.log $MAJORS[0] upgr >/dev/null") == 0);

# Upgrade to latest version
my $outref;
is ((exec_as 0, "pg_upgradecluster -v $MAJORS[-1] $MAJORS[0] upgr", $outref, 0), 0, 'pg_upgradecluster succeeds');
like $$outref, qr/Starting upgraded cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

# Check clusters
like_program_out 'nobody', 'pg_lsclusters -h', 0,
    qr"$MAJORS[0] +upgr 5433 down   postgres /tmp/postgresql-test +/tmp/postgresql-test.log\n$MAJORS[-1] +upgr 5432 online postgres /var/lib/postgresql/$MAJORS[-1]/upgr +/var/log/postgresql/postgresql-$MAJORS[-1]-upgr.log", 'pg_lsclusters output';

# clean away new cluster and restart the old one
is ((system "pg_dropcluster $MAJORS[-1] upgr --stop"), 0, 'Dropping upgraded cluster');
is_program_out 0, "pg_ctlcluster $MAJORS[0] upgr start", 0, '', 'Restarting old cluster';
is_program_out 'nobody', 'pg_lsclusters -h', 0, 
    "$MAJORS[0] upgr 5433 online postgres /tmp/postgresql-test /tmp/postgresql-test.log
", 'pg_lsclusters output';

# Do another upgrade with using a custom defined data directory (and in passing, test --keep-port)
my $outref;
is ((exec_as 0, "pg_upgradecluster --keep-port -v $MAJORS[-1] $MAJORS[0] upgr /tmp/psql-common-testsuite", $outref, 0), 0, 'pg_upgradecluster succeeds');
unlike $$outref, qr/^pg_restore: /m, 'no pg_restore error messages during upgrade';
unlike $$outref, qr/^[A-Z]+:  /m, 'no server error messages during upgrade';
like $$outref, qr/Starting upgraded cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

like_program_out 'nobody', 'pg_lsclusters -h', 0,
    qr"$MAJORS[0] +upgr 5433 down   postgres /tmp/postgresql-test +/tmp/postgresql-test.log\n$MAJORS[-1] +upgr 5432 online postgres /tmp/psql-common-testsuite +/var/log/postgresql/postgresql-$MAJORS[-1]-upgr.log", 'pg_lsclusters output';

# stop servers, clean up
is ((system "pg_dropcluster $MAJORS[0] upgr"), 0, 'Dropping original cluster');
is ((system "pg_dropcluster $MAJORS[-1] upgr --stop"), 0, 'Dropping upgraded cluster');

check_clean;

# vim: filetype=perl
