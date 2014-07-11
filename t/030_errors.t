# Check all kinds of error conditions.

use strict; 

require File::Temp;

use lib 't';
use TestLib;
use Test::More tests => 158;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $version = $MAJORS[-1];

my $socketdir = '/tmp/postgresql-testsuite/';
my ($pg_uid, $pg_gid) = (getpwnam 'postgres')[2,3];

# create a pid file with content $1 and return its path
sub create_pidfile {
    my $fname = "/var/lib/postgresql/$version/main/postmaster.pid";
    open F, ">$fname" or die "open: $!";
    print F $_[0];
    close F;
    chown $pg_uid, $pg_gid, $fname or die "chown: $!";
    chmod 0700, $fname or die "chmod: $!";
    return $fname;
}

sub check_nonexisting_cluster_error {
    my $outref;
    my $result = exec_as 0, $_[0], $outref;
    is $result, 1, "'$_[0]' fails";
    like $$outref, qr/(invalid version|does not exist|cannot upgrade)/i, "$_[0] gives error message about nonexisting cluster";
    unlike $$outref, qr/invalid symbolic link/i, "$_[0] does not print 'invalid symbolic link' gibberish";
}

# create cluster
ok ((system "pg_createcluster --socketdir '$socketdir' $version main >/dev/null") == 0,
    "pg_createcluster --socketdir");
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$version\s*main.*5432.*down/, 'cluster was created';

is ((get_cluster_port $version, 'main'), 5432, 'Port of created cluster is 5432');

# creating cluster with the same name should fail
like_program_out 'root', "pg_createcluster --socketdir '$socketdir' $version main", 1, qr/already exists/,
    "pg_createcluster on existing cluster";
# and the original one still exists
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$version\s*main.*5432.*down/, 'original cluster still exists';

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
my $badid = 98;
(system "chown -R $badid /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start 2>/dev/null"), 256,
    'pg_ctlcluster fails on invalid cluster owner uid');
(system "chown -R postgres:$badid /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start 2>/dev/null"), 256,
    'pg_ctlcluster as root fails on invalid cluster owner gid');
is ((exec_as 'postgres', "pg_ctlcluster $version main start"), 1,
    'pg_ctlcluster as postgres fails on invalid cluster owner gid');
(system "chown -R postgres:postgres /var/lib/postgresql/$version/main") == 0 or die "chown failed: $!";
is ((system "pg_ctlcluster $version main start"), 0,
    'pg_ctlcluster succeeds on valid cluster owner uid/gid');

# check socket
ok_dir '/var/run/postgresql', ["$version-main.pid"], 'No sockets in /var/run/postgresql';
ok_dir $socketdir, ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], "Socket is in $socketdir";

# stop cluster, check sockets
ok ((system "pg_ctlcluster $version main stop") == 0,
    'cluster stops with custom unix_socket_dir');
ok_dir $socketdir, [], "No sockets in $socketdir after stopping cluster";

# remove default socket dir and check that the socket defaults to
# /var/run/postgresql
open F, "+</etc/postgresql/$version/main/postgresql.conf" or
    die "could not open postgresql.conf for r/w: $!";
my @lines = <F>;
seek F, 0, 0 or die "seek: $!";
truncate F, 0;
@lines = grep !/^unix_socket_dir/, @lines; # <= 9.2: "_directory", >= 9.3: "_directories"
print F @lines;
close F;

ok ((system "pg_ctlcluster $version main start") == 0,
    'cluster starts after removing unix_socket_dir');
if ($PgCommon::rpm) {
    ok ((grep { $_ eq '.s.PGSQL.5432' } @{TestLib::dircontent('/tmp')}) == 1, 'Socket is in /tmp');
} else {
    ok_dir '/var/run/postgresql', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock', "$version-main.pid"], 
        'Socket is in default dir /var/run/postgresql';
}
ok_dir $socketdir, [], "No sockets in $socketdir";

# server should not stop with corrupt file
rename "/var/lib/postgresql/$version/main/postmaster.pid",
    "/var/lib/postgresql/$version/main/postmaster.pid.orig" or die "rename: $!";
create_pidfile 'foo';
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
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';
ok (! -e "/var/lib/postgresql/$version/main/postmaster.pid", 'no pid file left');

# trying to stop a stopped server cleans up corrupt and stale pid files
my $pf = create_pidfile 'foo';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 2,
    "Removed stale pid file.\nCluster is not running.\n", 
    'pg_ctlcluster stop succeeds with corrupted PID file';
ok (! -e $pf, 'pid file was cleaned up');

create_pidfile 'foo';
is_program_out 'postgres', "pg_ctlcluster --force $version main stop", 2,
    "Removed stale pid file.\nCluster is not running.\n", 
    'pg_ctlcluster --force stop succeeds with corrupted PID file';
ok (! -e $pf, 'pid file was cleaned up');

create_pidfile '99998';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 2,
    "Removed stale pid file.\nCluster is not running.\n", 
    'pg_ctlcluster stop succeeds with stale PID file';
ok (! -e $pf, 'pid file was cleaned up');

create_pidfile '99998';
is_program_out 'postgres', "pg_ctlcluster --force $version main stop", 2,
    "Removed stale pid file.\nCluster is not running.\n", 
    'pg_ctlcluster --force stop succeeds with stale PID file';
ok (! -e $pf, 'pid file was cleaned up');

create_pidfile '';
is_program_out 'postgres', "pg_ctlcluster --force $version main stop", 2,
    "Removed stale pid file.\nCluster is not running.\n", 
    'pg_ctlcluster stop succeeds with empty PID file';
ok (! -e $pf, 'pid file was cleaned up');

# corrupt PID file while server is down
create_pidfile 'foo';
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

if ($version < '8.4') {
    like_program_out 'postgres', "pg_ctlcluster $version main start", 0, 
	qr/WARNING.*connection to the database failed.*pg_hba.conf/is,
	'pg_ctlcluster start warns about invalid pg_hba.conf';
    is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';
} else {
    like_program_out 'postgres', "pg_ctlcluster $version main start", 1, 
	qr/FATAL.*pg_hba.conf/is,
	'pg_ctlcluster start fails on invalid pg_hba.conf';
    is_program_out 'postgres', "pg_ctlcluster $version main stop", 2, 
	"Cluster is not running.\n", 'stopping cluster';
}

# test check for pg_hba.conf with removed passwordless local superuser access
open F, ">/etc/postgresql/$version/main/pg_hba.conf" or die "could not create pg_hba.conf: $!";
print F "local all all md5\n";
close F;
chmod 0644, "/etc/postgresql/$version/main/pg_hba.conf" or die "chmod: $!";

like_program_out 'postgres', "pg_ctlcluster $version main start", 0,
    qr/WARNING.*connection to the database failed.*postgres/is,
    'pg_ctlcluster start warns about absence of passwordless superuser connection';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';

# restore pg_hba.conf
unlink "/etc/postgresql/$version/main/pg_hba.conf";
rename "/etc/postgresql/$version/main/pg_hba.conf.orig",
    "/etc/postgresql/$version/main/pg_hba.conf" or die "rename: $!";

# leftover files must not create confusion
open F, '>/etc/postgresql/postgresql.conf';
print F "data_directory = '/nonexisting'\n";
close F;
my @c = get_version_clusters $version;
is_deeply (\@c, ['main'], 
   'leftover /etc/postgresql/postgresql.conf is not regarded as a cluster');
unlink '/etc/postgresql/postgresql.conf';

# fails by default due to access restrictions
# remove cluster and directory; this should work as user "postgres"
is_program_out 'postgres', "pg_dropcluster $version main", 0, '',
    , "pg_dropcluster works as user postgres";

# graceful handling of absent data dir (might not be mounted)
ok ((system "pg_createcluster $version main >/dev/null") == 0,
    "pg_createcluster succeeds");
rename "/var/lib/postgresql/$version", "/var/lib/postgresql/$version.orig" or die "rename: $!";
my $outref;
is ((exec_as 0, "pg_ctlcluster $version main start", $outref, 1), 1,
    'pg_ctlcluster fails on nonexisting /var/lib/postgresql');
like $$outref, qr/^Error:.*\/var\/lib\/postgresql.*not accessible.*$/, 'proper error message for nonexisting /var/lib/postgresql';

rename "/var/lib/postgresql/$version.orig", "/var/lib/postgresql/$version" or die "rename: $!";
is_program_out 'postgres', "pg_ctlcluster $version main start", 0, '',
    'pg_ctlcluster start succeeds again with reappeared /var/lib/postgresql';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 'stopping cluster';

# pg_ctlcluster checks colliding ports
ok ((system "pg_createcluster $version other >/dev/null") == 0,
    "pg_createcluster other");
set_cluster_port $version, 'other', '5432';
is ((exec_as 'postgres', "pg_ctlcluster $version main start"), 0,
    'pg_ctlcluster: main cluster on conflicting port starts');

# clusters can run side by side on different socket directories
set_cluster_socketdir $version, 'other', $socketdir;
PgCommon::set_conf_value $version, 'other', 'postgresql.conf',
    'listen_addresses', ''; # otherwise they will conflict on TCP socket
is ((exec_as 'postgres', "pg_ctlcluster $version other start"), 0,
    'pg_ctlcluster: other cluster starts on conflicting port, but different socket dirs');
is ((exec_as 'postgres', "pg_ctlcluster $version other stop"), 0);

# ... but will give an error when running on the same port
set_cluster_socketdir $version, 'other', $PgCommon::rpm ? '/tmp' : '/var/run/postgresql';
like_program_out 'postgres', "pg_ctlcluster $version other start", 1,
    qr/Port conflict:.*port 5432/,
    'pg_ctlcluster other cluster fails on conflicting port and same socket dir';
is_program_out 'postgres', "pg_ctlcluster $version main stop", 0, '', 
    'stopping main cluster';
is ((exec_as 'postgres', "pg_ctlcluster $version other start"), 0,
    'pg_ctlcluster: other cluster on conflicting port starts after main is down');
ok ((system "pg_dropcluster $version other --stop") == 0, 
    'pg_dropcluster other');

# clean up
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
