# Check upgrade scripts

use strict; 

use lib 't';
use TestLib;

my @versions = ($MAJORS[-1]);

use Test::More tests => 29;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $shellaction = '#!/bin/sh
S=`basename $0`
su postgres <<EOF
psql --cluster "$1/$2" db1 -c "INSERT INTO log VALUES (\'$S $1 $2 $3\')"
EOF
';

my %test_sql_scripts = (
    'all_all-sql-db_db.sql' => 'CREATE TABLE dbt(x int)',
    'all_all-sql-t1_t1.sql' => 'CREATE TABLE t1t(x int)',
    'all_all-sql-t0_t0.sql' => 'CREATE TABLE t0t(x int)',
    '1_1-sql-db_db.sql' => 'CREATE TABLE v1t(x int)',
    '2_2-sql-db_db.sql' => 'CREATE TABLE v2t(x int)',
    'all_all-sql-cluster_cluster.sql' => 'SELECT datname from pg_databases',

    'all_all-sh-db_db.sh' => $shellaction,
    'all_all-sh-t1_t1.sh' => $shellaction,
    'all_all-sh-t0_t0.sh' => $shellaction,
    '1_1-sh-db_db.sh' =>  $shellaction,
    '2_2-sh-db_db.sh' =>  $shellaction,
    'all_all-sh-cluster_cluster.sh' =>  $shellaction,
    'all_all-shfail-cluster_cluster.sh' => 'echo "all-shfail-cluster:fail"; exit 1',
    'all_all-shnoexec-t0_t0.sh' => $shellaction
);

# create clusters
foreach my $v (@versions) {
    is ((system "pg_createcluster $v main --start >/dev/null"), 0, "pg_createcluster $v main");
    is_program_out 'postgres', "createdb --cluster $v/main db1", 0, '';
    is_program_out 'postgres', "createdb --cluster $v/main db2", 0, '';
    is_program_out 'postgres', "psql -q --cluster $v/main db1 -c 'CREATE TABLE log (str varchar)'", 0, '';
    my @dbs = get_cluster_databases $v, 'main';
    my @expected = ('template0', 'template1', 'db1', 'db2', 'postgres');
    if (eq_set \@dbs, \@expected) {
        pass 'get_cluster_databases() works';
    } else {
        fail "get_cluster_databases: got '@dbs', expected '@expected'";
    }
}


# create scripts
my $scriptdir = '/usr/share/postgresql-common/upgrade-scripts';
ok_dir $scriptdir, ['SPECIFICATION'], "$scriptdir has no scripts (for the test)";

for my $n (keys %test_sql_scripts) {
    open F, ">$scriptdir/$n" or die "could not create $scriptdir/$n: $!";
    print F $test_sql_scripts{$n};
    close F;
    if ($n =~ /\.sh$/ && $n !~ /noexec/) {
	chmod 0755, "$scriptdir/$n";
    } else {
	chmod 0644, "$scriptdir/$n";
    }
}

# call run-upgrade-scripts
my $outref;
is ((exec_as 0, '/usr/share/postgresql-common/run-upgrade-scripts 2 2>&1', $outref),
    0, 'run-upgrade-scripts succeeds');

is $$outref, "Executing upgrade script 2-sh-db...
  cluster $versions[0]/main: db1 db2
Executing upgrade script 2-sql-db...
  cluster $versions[0]/main: db1 db2
Executing upgrade script all-sh-cluster...
  cluster $versions[0]/main: template1
Executing upgrade script all-sh-db...
  cluster $versions[0]/main: db1 db2
Executing upgrade script all-sh-t0...
  cluster $versions[0]/main: db1 db2 template0 template1
Executing upgrade script all-sh-t1...
  cluster $versions[0]/main: db1 db2 template1
Executing upgrade script all-shfail-cluster...
  cluster $versions[0]/main: template1[FAIL]
all-shfail-cluster:fail

Executing upgrade script all-sql-cluster...
  cluster $versions[0]/main: template1
Executing upgrade script all-sql-db...
  cluster $versions[0]/main: db1 db2
Executing upgrade script all-sql-t0...
  cluster $versions[0]/main: db1 db2 template0 template1
Executing upgrade script all-sql-t1...
  cluster $versions[0]/main: db1 db2 template1
", 'correct run-upgrade-script output';

# check tables created by SQL scripts
foreach my $v (@versions) {
    is_program_out 'postgres', 
        "psql --cluster $v/main db1 -Atc \"select tablename from pg_tables where schemaname = 'public' order by tablename\"",
        0, "dbt\nlog\nt0t\nt1t\nv2t\n", "check SQL scripts results in $v/main db1";
    is_program_out 'postgres', 
        "psql --cluster $v/main db2 -Atc \"select tablename from pg_tables where schemaname = 'public' order by tablename\"",
        0, "dbt\nt0t\nt1t\nv2t\n", "check SQL scripts results in $v/main db2";
}

# check log created by shell scripts
foreach my $v (@versions) {
    is_program_out 'postgres',
        "psql --cluster $v/main db1 -Atc 'select * from log order by str'",
        0, "2_2-sh-db_db.sh $v main db1
2_2-sh-db_db.sh $v main db2
all_all-sh-cluster_cluster.sh $v main template1
all_all-sh-db_db.sh $v main db1
all_all-sh-db_db.sh $v main db2
all_all-sh-t0_t0.sh $v main db1
all_all-sh-t0_t0.sh $v main db2
all_all-sh-t0_t0.sh $v main template0
all_all-sh-t0_t0.sh $v main template1
all_all-sh-t1_t1.sh $v main db1
all_all-sh-t1_t1.sh $v main db2
all_all-sh-t1_t1.sh $v main template1
", 'check shell scripts results in $v/main';
}

# clean up
for my $n (keys %test_sql_scripts) {
    unlink "$scriptdir/$n" or die "could not remove $scriptdir/$n: $!";
}

ok_dir $scriptdir, ['SPECIFICATION'], "$scriptdir has no test suite scripts any more";

foreach (@versions) {
    is ((system "pg_dropcluster $_ main --stop"), 0, "pg_dropcluster $_ main");
}

check_clean;

# vim: filetype=perl
