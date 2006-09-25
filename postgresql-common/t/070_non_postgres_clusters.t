# Test successful operation of clusters which are not owned by
# postgres. Only check the oldest and newest version.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 32;

my $owner = 'nobody';

# create cluster
for my $v (@MAJORS[0, -1]) {
    is ((system "pg_createcluster -u $owner $v main --start >/dev/null"), 0,
        "pg_createcluster $v main for owner $owner");

    # Check cluster
    like_program_out $owner, 'pg_lsclusters -h', 0, 
        qr/^$v\s+main\s+5432\s+online\s+$owner/, 
        'pg_lsclusters shows running cluster';

    like ((ps 'postmaster'), qr/^$owner.*bin\/postmaster .*\/var\/lib\/postgresql\/$v\/main/,
        "postmaster is running as user $owner");

    is_program_out $owner, 'ls /tmp/.s.PGSQL.*', 0, "/tmp/.s.PGSQL.5432\n/tmp/.s.PGSQL.5432.lock\n", 'socket is in /tmp';

    ok_dir '/var/run/postgresql', [], '/var/run/postgresql is empty';
    
    # Check proper cleanup
    is ((system "pg_dropcluster $v main --stop"), 0, 'pg_dropcluster');
    is_program_out $owner, 'pg_lsclusters -h', 0, '', 'No clusters left';
    is ((ps 'postmaster'), '', 'No postmaster processes left');
}

check_clean;

# vim: filetype=perl
