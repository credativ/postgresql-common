# Check start.conf handling.

use strict; 

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 73;

my $systemd = -d '/run/systemd/system';

# Do test with oldest version
my $v = $MAJORS[0];

# create cluster
is ((system "pg_createcluster $v main >/dev/null"), 0, "pg_createcluster $v main");

# Check that we start with 'auto'
note "start.conf auto";
is ((get_cluster_start_conf $v, 'main'), 'auto', 
    'get_cluster_start_conf returns auto');
is_program_out 'nobody', "grep '^[^\\s#]' /etc/postgresql/$v/main/start.conf",
    0, "auto\n", 'start.conf contains auto';
SKIP: {
    skip 'not running under systemd', 2 unless ($systemd);
    ok_dir '/run/systemd/generator/postgresql.service.wants',
        ["postgresql\@$v-main.service"],
        "systemd generator links cluster";
    is ((readlink "/run/systemd/generator/postgresql.service.wants/postgresql\@$v-main.service"),
        "/lib/systemd/system/postgresql@.service",
        "systemd generator links correct service file");
}

# init script should handle auto cluster
like_program_out 0, "/etc/init.d/postgresql start $v", 0, qr/Start.*($v|systemctl)/;
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';
like_program_out 0, "/etc/init.d/postgresql stop $v", 0, qr/Stop.*($v|systemctl)/;
sleep 3 if ($systemd); # FIXME: systemctl stop postgresql is not yet synchronous (#759725)
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# change to manual, verify start.conf contents
note "start.conf manual";
set_cluster_start_conf $v, 'main', 'manual';

is ((get_cluster_start_conf $v, 'main'), 'manual', 
    'get_cluster_start_conf returns manual');
is_program_out 'nobody', "grep '^[^\\s#]' /etc/postgresql/$v/main/start.conf",
    0, "manual\n", 'start.conf contains manual';
SKIP: {
    skip 'not running under systemd', 1 unless ($systemd);
    system "systemctl daemon-reload";
    ok_dir '/run/systemd/generator/postgresql.service.wants',
        [], "systemd generator doesn't link cluster";
}

# init script should not handle manual cluster ...
like_program_out 0, "/etc/init.d/postgresql start $v", 0, qr/Start.*($v|systemctl)/;
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# pg_ctlcluster should handle manual cluster
is_program_out 'postgres', "pg_ctlcluster $v main start", 0, '';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';
is_program_out 'postgres', "pg_ctlcluster $v main stop", 0, '';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# change to disabled, verify start.conf contents
note "start.conf disabled";
set_cluster_start_conf $v, 'main', 'disabled';

is ((get_cluster_start_conf $v, 'main'), 'disabled', 
    'get_cluster_start_conf returns disabled');
SKIP: {
    skip 'not running under systemd', 1 unless ($systemd);
    system "systemctl daemon-reload";
    ok_dir '/run/systemd/generator/postgresql.service.wants',
        [], "systemd generator doesn't link cluster";
}

# init script should not handle disabled cluster
like_program_out 0, "/etc/init.d/postgresql start $v", 0, qr/Start.*($v|systemctl)/;
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# pg_ctlcluster should not start disabled cluster
is_program_out 'postgres', "pg_ctlcluster $v main start", 1, 
    "Error: Cluster is disabled\n";
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# change back to manual, start cluster
set_cluster_start_conf $v, 'main', 'manual';
is_program_out 'postgres', "pg_ctlcluster $v main start", 0, '';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';

# however, we want to stop disabled clusters
set_cluster_start_conf $v, 'main', 'disabled';
is_program_out 'postgres', "pg_ctlcluster $v main stop", 0, '';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/down/, 'cluster is down';

# set back to manual
set_cluster_start_conf $v, 'main', 'manual';
is_program_out 'postgres', "pg_ctlcluster $v main start", 0, '';
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/online/, 'cluster is online';

# upgrade cluster
note "test upgrade";
if ($#MAJORS == 0) {
    pass 'only one major version installed, skipping upgrade test';
    pass '...';
} else {
    like_program_out 0, "pg_upgradecluster -v $MAJORS[-1] $v main", 0, qr/Success/;
}

# check start.conf of old and upgraded cluster
is ((get_cluster_start_conf $v, 'main'), 'manual', 
    'get_cluster_start_conf for old cluster returns manual');
is ((get_cluster_start_conf $MAJORS[-1], 'main'), 'manual', 
    'get_cluster_start_conf for new cluster returns manual');

# clean up
if ($#MAJORS == 0) {
    pass '...';
} else {
    is ((system "pg_dropcluster $v main"), 0, 
        'dropping old cluster');
}

is ((system "pg_dropcluster $MAJORS[-1] main --stop"), 0, 
    'dropping upgraded cluster');

is_program_out 'postgres', 'pg_lsclusters -h', 0, '', 'no clusters any more';

# create cluster with --start-conf option
is_program_out 0, "pg_createcluster $v main --start-conf foo", 1, 
    "Error: Invalid --start-conf value: foo\n",
    'pg_createcluster checks --start-conf validity';
is ((system "pg_createcluster $v main --start-conf manual >/dev/null"), 0, 
    'pg_createcluster checks --start-conf manual');
is ((get_cluster_start_conf $v, 'main'), 'manual', 
    'get_cluster_start_conf returns manual');
is ((system "pg_dropcluster $v main"), 0, 
    'dropping cluster');

check_clean;

# vim: filetype=perl
