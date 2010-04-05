# Check /etc/p-c/pg_upgradecluster.d/ scripts and proper handling of already
# existing tables in the target cluster.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => ($#MAJORS == 0) ? 1 : 33;

if ($#MAJORS == 0) {
    pass 'only one major version installed, skipping upgrade tests';
    exit 0;
}

use lib '/usr/share/postgresql-common';
use PgCommon;

# create old cluster
is ((system "pg_createcluster $MAJORS[0] main --start >/dev/null"), 0, "pg_createcluster $MAJORS[0] main");

# add data table, auxtable with 'old...' values, and an unrelated auxtable in
# another schema
is_program_out 'postgres', 
    'psql template1 -qc "create table auxdata (x varchar(10)); insert into auxdata values (\'old1\'); insert into auxdata values (\'old2\')"',
    0, '', 'adding auxdata to template1 and fill in some "old..." values';
is_program_out 'postgres', "createdb test", 0, '';
is_program_out 'postgres', 'psql test -qc "create table userdata(x int); insert into userdata values(42); insert into userdata values(256)"',
    0, '', 'creating userdata table';
is_program_out 'postgres', 
    'psql test -qc "create schema s; create table s.auxdata (x varchar(10)); insert into s.auxdata values (\'schema1\')"',
    0, '', 'adding schema s and s.auxdata to test and fill in some values';

# move current pg_upgradecluster.d aside for the test
if (-d '/etc/postgresql-common/pg_upgradecluster.d') {
    ok ((rename '/etc/postgresql-common/pg_upgradecluster.d',
    '/etc/postgresql-common/pg_upgradecluster.d.psqltestsuite'),
    'Temporarily moving away /etc/postgresql-common/pg_upgradecluster.d');
} else {
    pass '/etc/postgresql-common/pg_upgradecluster.d does not exist';
}

# create test script
mkdir '/etc/postgresql-common/pg_upgradecluster.d' or die "mkdir: $!";
chmod 0755, '/etc/postgresql-common/pg_upgradecluster.d' or die "chmod: $!";
open F, '>/etc/postgresql-common/pg_upgradecluster.d/auxdata' or die "open: $!";
print F <<EOS;
#!/bin/sh -e
# Arguments: <old version> <cluster name> <new version> <phase>
oldver=\$1
cluster=\$2
newver=\$3
phase=\$4

if [ \$phase = init ]; then
    createdb --cluster \$newver/\$cluster idb
fi

if [ \$phase = finish ]; then
    psql --cluster \$newver/\$cluster template1 <<EOF
drop table if exists auxdata;
create table auxdata (x varchar(10));
insert into auxdata values ('new1');
insert into auxdata values ('new2');
EOF
fi

EOS
chmod 0755, '/etc/postgresql-common/pg_upgradecluster.d/auxdata' or die "chmod: $!";
close F;

# upgrade cluster
my $outref;
is ((exec_as 0, "pg_upgradecluster $MAJORS[0] main", $outref, 0), 0, 'pg_upgradecluster succeeds');
unlike $$outref, qr/^[A-Z]+:  /m, 'no server error messages during upgrade';
like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

is ((system "pg_dropcluster $MAJORS[0] main --stop"), 0, 'Dropping old cluster');

# check new version cluster
is_program_out 'postgres', 'psql template1 -Atc "select * from auxdata order by x"', 0,
   "new1\nnew2\n", 'new cluster\'s template1/auxdata table is the script\'s version';

like_program_out 'postgres', 'psql -Atl', 0, qr/^idb\b.*^test\b/ms, 
    'upgraded cluster has idb and test databases';

is_program_out 'postgres', 'psql test -Atc "select * from s.auxdata"', 0,
   "schema1\n", 'new cluster\'s test/auxdata table in schema s was upgraded normally';

# remove test script
unlink '/etc/postgresql-common/pg_upgradecluster.d/auxdata' or die "unlink: $!";
rmdir '/etc/postgresql-common/pg_upgradecluster.d' or die "rmdir: $!";

# restore original pg_upgradecluster.d
if (-f '/etc/postgresql-common/pg_upgradecluster.d.psqltestsuite') {
    ok ((rename '/etc/postgresql-common/pg_upgradecluster.d.psqltestsuite',
    '/etc/postgresql-common/pg_upgradecluster.d'),
    'Restoring original /etc/postgresql-common/pg_upgradecluster.d');
} else {
    pass '/etc/postgresql-common/pg_upgradecluster.d did not exist, not restoring';
}

# clean up
is ((system "pg_dropcluster $MAJORS[-1] main --stop"), 0, "pg_dropcluster $MAJORS[-1] main");
check_clean;

# vim: filetype=perl
