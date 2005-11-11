Creating new cluster (configuration: /etc/postgresql/7.4/pg74, data: /var/lib/postgresql/7.4/pg74)...
Moving configuration file /var/lib/postgresql/7.4/pg74/pg_hba.conf to /etc/postgresql/7.4/pg74...
Moving configuration file /var/lib/postgresql/7.4/pg74/pg_ident.conf to /etc/postgresql/7.4/pg74...
Moving configuration file /var/lib/postgresql/7.4/pg74/postgresql.conf to /etc/postgresql/7.4/pg74...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     pg74      5433 online postgres /var/lib/postgresql/7.4/pg74       /var/log/postgresql/postgresql-7.4-pg74.log 
Creating new cluster (configuration: /etc/postgresql/8.0/pg74, data: /var/lib/postgresql/8.0/pg74)...
Moving configuration file /var/lib/postgresql/8.0/pg74/pg_hba.conf to /etc/postgresql/8.0/pg74...
Moving configuration file /var/lib/postgresql/8.0/pg74/pg_ident.conf to /etc/postgresql/8.0/pg74...
Moving configuration file /var/lib/postgresql/8.0/pg74/postgresql.conf to /etc/postgresql/8.0/pg74...
Configuring postgresql.conf to use port 5432...
Dumping the old cluster into the new one...
Copying old configuration files...
Copying old start.conf...
Stopping target cluster...
Stopping old cluster...
Disabling automatic startup of old cluster...
Configuring old cluster to use a different port (5432)...
Starting target cluster on the original port...
Vacuuming and analyzing target cluster...
Doing maintenance on cluster 8.0/pg74...
Success. Please check that the upgraded cluster works. If it does,
you can remove the old cluster with

  pg_dropcluster 7.4 pg74
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     pg74      5433 online postgres /var/lib/postgresql/8.0/pg74       /var/log/postgresql/postgresql-8.0-pg74.log 
New configuration:
--------------------
#tcpip_socket = true #deprecated in favor of listen_addresses
listen_addresses = '*'
max_connections = 100
superuser_reserved_connections = 2
port = 5433
unix_socket_directory = '/var/run/postgresql'
unix_socket_group = ''
unix_socket_permissions = 0777
#virtual_host = '' #deprecated in favor of listen_addresses
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
#syslog = 0 #deprecated in favor of log_destination
log_destination = stderr
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
#log_pid = true #deprecated in favor of log_line_prefix
log_statement = all
#log_timestamp = true #deprecated in favor of log_line_prefix
#log_hostname = true #deprecated in favor of log_line_prefix
#log_source_port = true #deprecated in favor of log_line_prefix
log_parser_stats = false
log_planner_stats = false
log_executor_stats = false
stats_start_collector = true
stats_command_string = false
stats_block_level = false
stats_row_level = true
stats_reset_on_server_start = true
search_path = '$user,public'
default_transaction_isolation = 'read committed'
default_transaction_read_only = false
statement_timeout = 0
datestyle = 'ISO,European'
australian_timezones = false
extra_float_digits = 0
dynamic_library_path = '/usr/share/postgresql:/usr/lib/postgresql'
#max_expr_depth = 10000 #does not exist any more, look at max_stack_depth
deadlock_timeout = 1000
max_locks_per_transaction = 64
add_missing_from = true
regex_flavor = advanced
sql_inheritance = true
transform_null_equals = false
log_line_prefix = '%t [%p] %r'
--------------------
