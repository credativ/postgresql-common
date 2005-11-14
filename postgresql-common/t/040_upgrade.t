#!/usr/bin/perl -w
# Test upgrading from the oldest version to the latest, using the default
# configuration file.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 21;

# create cluster
ok ((system "pg_createcluster $MAJORS[0] upgr --start >/dev/null") == 0,
    "pg_createcluster $MAJORS[0] upgr");

# Create nobody user, test database, and put a table into it
is ((exec_as 'postgres', 'createuser nobody -D ' . (($MAJORS[0] > 8.09) ? '-R -s' : '-A') . '; createdb -O nobody test'), 
	0, 'Create nobody user and test database');
is ((exec_as 'nobody', 'psql test -c "create table phone (name varchar(255) PRIMARY KEY, tel int NOT NULL)"'), 
    0, 'create table');
is ((exec_as 'nobody', 'psql test -c "insert into phone values (\'Alice\', 2)"'), 0, 'insert Alice into phone table');
is ((exec_as 'nobody', 'psql test -c "insert into phone values (\'Bob\', 1)"'), 0, 'insert Bob into phone table');

# Check clusters
my $outref;
is ((exec_as 'nobody', 'pg_lsclusters -h', $outref), 0, 'pg_lsclusters succeeds');
$$outref =~ s/\s*$//;
is $$outref, "$MAJORS[0]     upgr      5432 online postgres /var/lib/postgresql/$MAJORS[0]/upgr       /var/log/postgresql/postgresql-$MAJORS[0]-upgr.log",
	'correct pg_lsclusters output';

# Check SELECT in original cluster
my $select_old;
is ((exec_as 'nobody', 'psql -tAc "select * from phone order by name" test', $select_old), 0, 'SELECT succeeds');
is ($$select_old, 'Alice|2
Bob|1
', 'check SELECT output');

# Upgrade to latest version
is ((exec_as 0, "pg_upgradecluster $MAJORS[0] upgr", $outref), 0, 'pg_upgradecluster succeeds');
like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Doing maintenance/, 'pg_upgradecluster reported successful maintenance';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

# Check clusters
is ((exec_as 'nobody', 'pg_lsclusters -h', $outref), 0, 'pg_lsclusters succeeds');
$$outref =~ s/\s*$//;
is $$outref, "$MAJORS[0]     upgr      5433 down   postgres /var/lib/postgresql/$MAJORS[0]/upgr       /var/log/postgresql/postgresql-$MAJORS[0]-upgr.log 
$LATEST_MAJOR     upgr      5432 online postgres /var/lib/postgresql/$LATEST_MAJOR/upgr       /var/log/postgresql/postgresql-$LATEST_MAJOR-upgr.log",
	'correct pg_lsclusters output';

# Check that SELECT output is identical
my $select_new;
is ((exec_as 'nobody', 'psql -tAc "select * from phone order by name" test', $select_new), 0, 'SELECT in upgraded cluster succeeds');
is ($$select_old, $$select_new, 'SELECT output is the same in original and upgraded cluster');

# stop servers, clean up
ok ((system "pg_dropcluster $MAJORS[0] upgr --stop-server") == 0, 
    'Dropping original cluster');
ok ((system "pg_dropcluster $LATEST_MAJOR upgr --stop-server") == 0, 
    'Dropping upgraded cluster');

# Check clusters
is ((exec_as 'postgres', 'pg_lsclusters -h', $outref), 0, 'pg_lsclusters succeeds');
is $$outref, '', 'empty pg_lsclusters output';

# vim: filetype=perl
