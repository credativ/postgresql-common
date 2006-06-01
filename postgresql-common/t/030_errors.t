# Check all kinds of error conditions.

use strict; 

use lib 't';
use TestLib;
use Test::More tests => 111;

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

sub check_nonexisting_cluster_error {
    my $outref;
    my $result = exec_as 0, $_[0], $outref;
    is $result, 1, "'$_[0]' fails";
    like $$outref, qr/(invalid version|does not exist)/i, "$_[0] gives error message about nonexisting cluster";
    unlike $$outref, qr/invalid symbolic link/i, "$_[0] does not print 'invalid symbolic link' gibberish";
}

# create cluster
ok ((system "pg_createcluster --socketdir '$socketdir' $version main >/dev/null") == 0,
    "pg_createcluster --socketdir");

is ((get_cluster_port $version, 'main'), 5432, 'Port of created cluster is 5432');

# attempt to create clusters with an invalid port
like_program_out 0, "pg_createcluster $version test -p foo", 1,
    qr/invalid.*number expected/,
    'pg_createcluster -p checks that port option is numeric';
like_program_out 0, "pg_createcluster $version test -p 42", 1,
    qr/must be a positive integer between/,
    'pg_createcluster -p checks valid port range';

# attempt to create a cluster with an already used port
like_program_out 0, "pg_createcluster $version test -p 5432", 1,
    qr/port 5432 is already used/,
    'pg_createcluster -p checks that port is already used';

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
is_program_out 'postgres', "pg_ctlcluster $version main stop", 2,
    "Cluster is not running.\n", 'pg_ctlcluster stop fails on stopped cluster';

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
is_program_out 'postgres', "pg_ctlcluster $version main start", 2,
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

# repair configuration
PgCommon::set_conf_value $version, 'main', 'postgresql.conf',
    'log_planner_stats', 'false';
is_program_out 'postgres', "pg_ctlcluster $version main start", 0, '',
    'pg_ctlcluster start succeeds again with valid configuration';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';

# backup pg_hba.conf
rename "/etc/postgresql/$version/main/pg_hba.conf",
    "/etc/postgresql/$version/main/pg_hba.conf.orig" or die "rename: $!";

# test check for invalid pg_hba.conf
open F, ">/etc/postgresql/$version/main/pg_hba.conf" or die "could not create pg_hba.conf: $!";
print F "foo\n";
close F;
chmod 0644, "/etc/postgresql/$version/main/pg_hba.conf" or die "chmod: $!";

like_program_out 'postgres', "pg_ctlcluster $version main start", 0, 
    qr/WARNING.*invalid pg_hba.conf/i,
    'pg_ctlcluster start warns about invalid pg_hba.conf';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';

# test check for pg_hba.conf with removed passwordless local superuser access
open F, ">/etc/postgresql/$version/main/pg_hba.conf" or die "could not create pg_hba.conf: $!";
print F "local all all md5\n";
close F;
chmod 0644, "/etc/postgresql/$version/main/pg_hba.conf" or die "chmod: $!";

like_program_out 'postgres', "pg_ctlcluster $version main start", 0,
    qr/WARNING.*pg_hba.conf.*passwordless/i,
    'pg_ctlcluster start warns about invalid pg_hba.conf';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';

# restore pg_hba.conf
unlink "/etc/postgresql/$version/main/pg_hba.conf";
rename "/etc/postgresql/$version/main/pg_hba.conf.orig",
    "/etc/postgresql/$version/main/pg_hba.conf" or die "rename: $!";

# remove cluster and directory
ok ((system "pg_dropcluster $version main") == 0, 
    'pg_dropcluster');
ok_dir $socketdir, [], 'No sockets any more';
rmdir $socketdir or die "rmdir: $!";

# ensure sane error messages for nonexisting clusters
check_nonexisting_cluster_error 'psql --cluster 4.5/foo';
check_nonexisting_cluster_error "psql --cluster $MAJORS[0]/foo";
check_nonexisting_cluster_error "pg_dropcluster 4.5 foo";
check_nonexisting_cluster_error "pg_dropcluster $MAJORS[0] foo";
check_nonexisting_cluster_error "pg_upgradecluster 4.5 foo";
check_nonexisting_cluster_error "pg_upgradecluster $MAJORS[0] foo";
check_nonexisting_cluster_error "pg_ctlcluster 4.5 foo stop";
check_nonexisting_cluster_error "pg_ctlcluster $MAJORS[0] foo stop";

check_clean;

# check that pg_dropcluster copes with partially existing cluster
# configurations (which can happen if the disk becomes full)

mkdir '/etc/postgresql/';
mkdir "/etc/postgresql/$MAJORS[-1]";
mkdir "/etc/postgresql/$MAJORS[-1]/broken" or die "mkdir: $!";
symlink "/var/lib/postgresql/$MAJORS[-1]/broken", "/etc/postgresql/$MAJORS[-1]/broken/pgdata" or die "symlink: $!";

unlike_program_out 0, "pg_dropcluster $MAJORS[-1] broken", 0, qr/error/i, 
    'pg_dropcluster cleans up broken cluster configuration (only /etc with pgdata)';

check_clean;

mkdir '/etc/postgresql/';
mkdir '/var/lib/postgresql/';
mkdir "/etc/postgresql/$MAJORS[-1]" and 
mkdir "/etc/postgresql/$MAJORS[-1]/broken";
mkdir "/var/lib/postgresql/$MAJORS[-1]";
mkdir "/var/lib/postgresql/$MAJORS[-1]/broken";
mkdir "/var/lib/postgresql/$MAJORS[-1]/broken/base" or die "mkdir: $!";
symlink "/var/lib/postgresql/$MAJORS[-1]/broken", "/etc/postgresql/$MAJORS[-1]/broken/pgdata" or die "symlink: $!";
open F, ">/etc/postgresql/$MAJORS[-1]/broken/postgresql.conf" or die "open: $!";
close F;
open F, ">/var/lib/postgresql/$MAJORS[-1]/broken/PG_VERSION" or die "open: $!";
close F;

unlike_program_out 0, "pg_dropcluster $MAJORS[-1] broken", 0, qr/error/i, 
    'pg_dropcluster cleans up broken cluster configuration (/etc with pgdata and postgresql.conf and partial /var)';

check_clean;

# vim: filetype=perl
