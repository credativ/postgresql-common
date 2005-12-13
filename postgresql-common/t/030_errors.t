#!/usr/bin/perl -w
# Check all kinds of error conditions.

use strict; 

use lib 't';
use TestLib;
use Test::More tests => 37;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $version = $MAJORS[-1];

my $socketdir = '/tmp/postgresql-testsuite/';
my ($pg_uid, $pg_gid) = (getpwnam 'postgres')[2,3];
mkdir $socketdir or die "mkdir: $!";
chown $pg_uid, 0, $socketdir or die "chown: $!";

sub create_foo_pid {
    open F, ">/var/lib/postgresql/$version/main/postmaster.pid" or die "open: $!";
    print F 'foo';
    close F;
    chown $pg_uid, $pg_gid, "/var/lib/postgresql/$version/main/postmaster.pid" or die "chown: $!";
    chmod 0700, "/var/lib/postgresql/$version/main/postmaster.pid" or die "chmod: $!";
}

# create cluster
ok ((system "pg_createcluster --socketdir '$socketdir' $version main >/dev/null") == 0,
    "pg_createcluster --socketdir");

# chown cluster to an invalid user to test error
(system "chown -R 99 /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start 2>/dev/null"), 256,
    'pg_ctlcluster fails on invalid cluster owner uid');
(system "chown -R postgres:99 /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start 2>/dev/null"), 256,
    'pg_ctlcluster as root fails on invalid cluster owner gid');
is ((exec_as 'postgres', "pg_ctlcluster $version main start"), 1,
    'pg_ctlcluster as postgres fails on invalid cluster owner gid');
(system "chown -R postgres:postgres /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start"), 0,
    'pg_ctlcluster succeeds on valid cluster owner uid/gid');

# check socket
ok_dir '/var/run/postgresql', [], 'No sockets in /var/run/postgresql';
ok_dir $socketdir, ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], "Socket is in $socketdir";

# stop cluster, check sockets
ok ((system "pg_ctlcluster $version main stop") == 0,
    'cluster stops after removing unix_socket_dir');
ok_dir $socketdir, [], "No sockets in $socketdir after stopping cluster";

# remove default socket dir and check that the socket defaults to
# /var/run/postgresql
open F, "+</etc/postgresql/$version/main/postgresql.conf" or
    die "could not open postgresql.conf for r/w: $!";
my @lines = <F>;
seek F, 0, 0 or die "seek: $!";
truncate F, 0;
@lines = grep !/^unix_socket_directory/, @lines;
print F @lines;
close F;

ok ((system "pg_ctlcluster $version main start") == 0,
    'cluster starts after removing unix_socket_dir');
ok_dir '/var/run/postgresql', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], 
    'Socket is in default dir /var/run/postgresql';
ok_dir $socketdir, [], "No sockets in $socketdir";

# server should not stop with corrupt file
rename "/var/lib/postgresql/$version/main/postmaster.pid",
    "/var/lib/postgresql/$version/main/postmaster.pid.orig" or die "rename: $!";
create_foo_pid;
is_program_out 'postgres', "pg_ctlcluster $version main stop", 1, 
    "Error: pid file is invalid, please manually kill the stale server process.\n",
    'pg_ctlcluster fails with corrupted PID file';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is still online';

# restore PID file
(system "cp /var/lib/postgresql/$version/main/postmaster.pid.orig /var/lib/postgresql/$version/main/postmaster.pid") == 0 or die "cp: $!";
is ((exec_as 'postgres', "pg_ctlcluster $version main stop"), 0, 
    'pg_ctlcluster succeeds with restored PID file');
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# stop stopped server
is_program_out 'postgres', "pg_ctlcluster $version main stop", 1,
    "Error: cluster is not running\n", 'pg_ctlcluster stop fails on stopped cluster';

# simulate crashed server
rename "/var/lib/postgresql/$version/main/postmaster.pid.orig",
    "/var/lib/postgresql/$version/main/postmaster.pid" or die "rename: $!";
is_program_out 'postgres', "pg_ctlcluster $version main start", 0, 
    "Removed stale pid file.\n", 'pg_ctlcluster succeeds with already existing PID file';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';
is ((exec_as 'postgres', "pg_ctlcluster $version main stop"), 0, 
    'pg_ctlcluster stop succeeds');

# corrupt PID file while server is down
create_foo_pid;
is_program_out 'postgres', "pg_ctlcluster $version main start", 0,
    "Removed stale pid file.\n", 'pg_ctlcluster succeeds with corrupted PID file';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';

# start running server
is_program_out 'postgres', "pg_ctlcluster $version main start", 1,
    "Cluster is already running.\n", 'pg_ctlcluster start fails on running cluster';

# stop server, test invalid configuration
is ((exec_as 'postgres', "pg_ctlcluster $version main stop"), 0, 'pg_ctlcluster stop');
PgCommon::set_conf_value $version, 'main', 'postgresql.conf',
    'log_statement_stats', 'true';
PgCommon::set_conf_value $version, 'main', 'postgresql.conf',
    'log_planner_stats', 'true';
like_program_out 'postgres', "pg_ctlcluster $version main start", 1,
    qr/Error: invalid postgresql.conf.*log_.*mutually exclusive/,
    'pg_ctlcluster start fails with invalid configuration';

# remove cluster and directory
ok ((system "pg_dropcluster $version main") == 0, 
    'pg_dropcluster');
ok_dir $socketdir, [], 'No sockets any more';
rmdir $socketdir or die "rmdir: $!";

# vim: filetype=perl
