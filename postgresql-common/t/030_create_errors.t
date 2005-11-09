#!/usr/bin/perl -w
# Create a cluster with a nonstandard socket directory. Also check various
# error conditions of the cluster state.

use strict; 

use lib 't';
use TestLib;
use Test::More tests => 9;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $socketdir = '/tmp/postgresql-testsuite/';
mkdir $socketdir or die "mkdir: $!";
chown scalar (getpwnam 'postgres'), 0, $socketdir or die "chown: $!";

# create cluster
ok ((system "pg_createcluster --socketdir '$socketdir' 7.4 main >/dev/null") == 0,
    "pg_createcluster --socketdir");

# chown cluster to an invalid user to test error
(system 'chown -R 99 /var/lib/postgresql/7.4/main') == 0 or die "chown failed: $!";
is ((system 'pg_ctlcluster -s 7.4 main start 2>/dev/null'), 256,
    'pg_ctlcluster fails on invalid cluster owner uid');
(system 'chown -R postgres:99 /var/lib/postgresql/7.4/main') == 0 or die "chown failed: $!";
is ((system 'pg_ctlcluster -s 7.4 main start 2>/dev/null'), 256,
    'pg_ctlcluster as root fails on invalid cluster owner gid');
is ((exec_as 'postgres', 'pg_ctlcluster 7.4 main start'), 1,
    'pg_ctlcluster as postgres fails on invalid cluster owner gid');
(system 'chown -R postgres:postgres /var/lib/postgresql/7.4/main') == 0 or die "chown failed: $!";
is ((system 'pg_ctlcluster -s 7.4 main start'), 0,
    'pg_ctlcluster succeeds on valid cluster owner uid/gid');

# check socket
ok_dir '/var/run/postgresql', [], 'No sockets in /var/run/postgresql';
ok_dir $socketdir, ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], "Socket is in $socketdir";

# remove cluster and directory
ok ((system "pg_dropcluster 7.4 main --stop-server") == 0, 
    'pg_dropcluster');
ok_dir $socketdir, [], 'No sockets any more';
rmdir $socketdir or die "rmdir: $!";

# vim: filetype=perl
