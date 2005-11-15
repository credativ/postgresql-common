#!/usr/bin/perl -w
# Test upgrading from the oldest version to all majors with all possible
# configuration parameters set. This checks that they are correctly
# transitioned.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 7 + $#MAJORS * 5;

# create cluster
is ((system "pg_createcluster $MAJORS[0] main >/dev/null"), 0, "pg_createcluster $MAJORS[0] main");

open F, ">/etc/postgresql/$MAJORS[0]/main/postgresql.conf" or 
    die "could not open /etc/postgresql/$MAJORS[0]/main/postgresql.conf";
print F "
tcpip_socket = true
max_connections = 100
superuser_reserved_connections = 2
port = 5433
unix_socket_directory = '/var/run/postgresql'
unix_socket_group = ''
unix_socket_permissions = 0777
virtual_host = ''
rendezvous_name = ''
authentication_timeout = 60
ssl = false
password_encryption = true
krb_server_keyfile = ''
db_user_namespace = false
shared_buffers = 1000
sort_mem = 1024
vacuum_mem = 8192
max_fsm_pages = 20000
max_fsm_relations = 1000
max_files_per_process = 1000
preload_libraries = ''
fsync = true
wal_sync_method = fsync
wal_buffers = 8
checkpoint_segments = 3
checkpoint_timeout = 300
checkpoint_warning = 30
commit_delay = 0
commit_siblings = 5
enable_hashagg = true
enable_hashjoin = true
enable_indexscan = true
enable_mergejoin = true
enable_nestloop = true
enable_seqscan = true
enable_sort = true
enable_tidscan = true
effective_cache_size = 1000
random_page_cost = 4
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.001
cpu_operator_cost = 0.0025
geqo = true
geqo_threshold = 11
geqo_effort = 1
geqo_generations = 0
geqo_pool_size = 0
geqo_selection_bias = 2.0
default_statistics_target = 10
from_collapse_limit = 8
join_collapse_limit = 8
syslog = 0
syslog_facility = 'LOCAL0'
syslog_ident = 'postgres'
client_min_messages = notice
log_min_messages = notice
log_error_verbosity = default
log_min_error_statement = panic
log_min_duration_statement = -1
silent_mode = false
debug_print_parse = false
debug_print_rewritten = false
debug_print_plan = false
debug_pretty_print = false
log_connections = true
log_duration = false
log_pid = true
log_statement = true
log_timestamp = true
log_hostname = true
log_source_port = true
log_parser_stats = false
log_planner_stats = false
log_executor_stats = false
stats_start_collector = true
stats_command_string = false
stats_block_level = false
stats_row_level = true
stats_reset_on_server_start = true
search_path = '\$user,public'
default_transaction_isolation = 'read committed'
default_transaction_read_only = false
statement_timeout = 0
datestyle = 'ISO,European'
australian_timezones = false
extra_float_digits = 0
dynamic_library_path = '/usr/share/postgresql:/usr/lib/postgresql'
max_expr_depth = 10000
deadlock_timeout = 1000
max_locks_per_transaction = 64
add_missing_from = true
regex_flavor = advanced
sql_inheritance = true
transform_null_equals = false
";

is ((exec_as 'postgres', "pg_ctlcluster $MAJORS[0] main start 2>/dev/null"), 0,
    'pg_ctlcluster start');

# Check clusters
like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$MAJORS[0].*online/;

my $oldv = $MAJORS[0];
my @testv = @MAJORS;
shift @testv;
for my $v (@testv) {
    # Upgrade cluster
    like_program_out 0, "pg_upgradecluster -v $v $oldv main", 0, qr/^Success/im;

    # remove old cluster and directory
    is ((system "pg_dropcluster $oldv main"), 0, 'pg_dropcluster old cluster');

    # Check clusters
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$v.*online/, 
        'pg_lsclusters shows running upgraded cluster';

    $oldv = $v;
}

# remove latest cluster and directory
is ((system "pg_dropcluster $MAJORS[-1] main --stop-server"), 0, 'pg_dropcluster');

# Check clusters
is_program_out 'postgres', 'pg_lsclusters -h', 0, '', 'empty pg_lsclusters output';

# vim: filetype=perl
