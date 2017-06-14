use strict;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 20;

my $v = $MAJORS[-1];

# create cluster
ok ((system "pg_createcluster $v main --start >/dev/null") == 0,
    "pg_createcluster $v main");

# test pg_renamecluster with a running cluster
program_ok (0, "pg_renamecluster $v main donau");
is_program_out 'postgres', 'psql -tAc "show data_directory"', 0,
    "/var/lib/postgresql/$v/donau\n", 'cluster is running and data_directory was moved';
is ((PgCommon::get_conf_value $v, 'donau', 'postgresql.conf', 'hba_file'),
    "/etc/postgresql/$v/donau/pg_hba.conf", 'pg_hba.conf location updated');
is ((PgCommon::get_conf_value $v, 'donau', 'postgresql.conf', 'ident_file'),
    "/etc/postgresql/$v/donau/pg_ident.conf", 'pg_ident.conf location updated');
is ((PgCommon::get_conf_value $v, 'donau', 'postgresql.conf', 'external_pid_file'),
    "/var/run/postgresql/$v-donau.pid", 'external_pid_file location updated');
ok (-f "/var/run/postgresql/$v-donau.pid", 'external_pid_file exists');
SKIP: {
    skip "no stats_temp_directory in $v", 2 if ($v < 8.4);
    is ((PgCommon::get_conf_value $v, 'donau', 'postgresql.conf', 'stats_temp_directory'),
        "/var/run/postgresql/$v-donau.pg_stat_tmp", 'stats_temp_directory location updated');
    ok (-d "/var/run/postgresql/$v-donau.pg_stat_tmp", 'stats_temp_directory exists');
}
SKIP: {
    skip "cluster name not supported in $v", 1 if ($v < 9.5);
    is (PgCommon::get_conf_value ($v, 'donau', 'postgresql.conf', 'cluster_name'), "$v/donau", "cluster_name is updated");
}

# stop server, clean up, check for leftovers
ok ((system "pg_dropcluster $v donau --stop") == 0,
    'pg_dropcluster removes cluster');

check_clean;

# vim: filetype=perl
