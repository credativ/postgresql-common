# Test successful operation of clusters which are not owned by
# postgres. Only check the oldest and newest version.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 24;

my $owner = 'nobody';
my $v = $MAJORS[0];

# create cluster
is ((system "pg_createcluster -u $owner $v main --start >/dev/null"), 0,
    "pg_createcluster $v main for owner $owner");

# Check cluster
like_program_out $owner, 'pg_lsclusters -h', 0, 
    qr/^$v\s+main\s+5432\s+online\s+$owner/, 
    'pg_lsclusters shows running cluster';

my $master_process = ($v ge '8.2') ? 'postgres' : 'postmaster';
like ((ps $master_process), qr/^$owner.*bin\/$master_process .*\/var\/lib\/postgresql\/$v\/main/m,
    "$master_process is running as user $owner");

is_program_out $owner, 'ls /tmp/.s.PGSQL.*', 0, "/tmp/.s.PGSQL.5432\n/tmp/.s.PGSQL.5432.lock\n", 'socket is in /tmp';

ok_dir '/var/run/postgresql', [], '/var/run/postgresql is empty';

# verify log file properties
my @logstat = stat "/var/log/postgresql/postgresql-$v-main.log";
is $logstat[2], 0100640, 'log file has 0640 permissions';
is $logstat[4], (getpwnam $owner)[2], 'log file is owned by user';
is $logstat[5], (getpwnam $owner)[3], 'log file is owned by user\'s primary group';

# Check proper cleanup
is ((system "pg_dropcluster $v main --stop"), 0, 'pg_dropcluster');
is_program_out $owner, 'pg_lsclusters -h', 0, '', 'No clusters left';
is ((ps 'postmaster'), '', 'No postmaster processes left');

check_clean;

# vim: filetype=perl
