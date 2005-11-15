#!/usr/bin/perl -w
# Test successful operation of clusters which are not owned by
# postgres. Only check the oldest and newest version.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 18;

my $owner = 'nobody';

# create cluster
for my $v (@MAJORS[0, -1]) {
    ok ((system "pg_createcluster -u $owner $v main --start >/dev/null") == 0,
        "pg_createcluster $v main for owner $owner");

    # Check cluster
    like_program_out $owner, 'pg_lsclusters -h', 0, 
        qr/^$v\s+main\s+5432\s+online\s+$owner/, 
        'pg_lsclusters shows running cluster';

    like ((ps 'postmaster'), qr/^$owner.*bin\/postmaster .*unix_socket_directory=\/tmp/,
        "postmaster is running as user $owner");

    ok_dir '/var/run/postgresql', [], '/var/run/postgresql is empty';
    
    # Check proper cleanup
    is ((system "pg_dropcluster $v main --stop-server"), 0, 'pg_dropcluster');
    is_program_out $owner, 'pg_lsclusters -h', 0, '', 'No clusters left';
    is ((ps 'postmaster'), '', 'No postmaster processes left');
}

# vim: filetype=perl
