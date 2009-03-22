# Check pg_ctl.conf handling.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 31;

# Do test with newest version
my $v = $MAJORS[-1];

is ((system "pg_createcluster $v main >/dev/null"), 0, "pg_createcluster $v main");

ok (-f "/etc/postgresql/$v/main/pg_ctl.conf", "/etc/postgresql/$v/main/pg_ctl.conf exists");

# Default behaviour, core size=0
is_program_out 'postgres', "pg_ctlcluster $v main start", 0, '', "starting cluster";

is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "0\n", "soft core size is 0";

# -c in pg_ctl.conf, core size=unlimited
ok (set_cluster_pg_ctl_conf($v, 'main', '-c'), "set pg_ctl default option to -c");

is_program_out 'postgres', "pg_ctlcluster $v main restart", 0, '', "restarting cluster";

is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "unlimited\n", "soft core size is unlimited";

# Back to default behaviour, core size=0

ok (set_cluster_pg_ctl_conf($v, 'main', ''), "restored pg_ctl default option");

is_program_out 'postgres', "pg_ctlcluster $v main restart", 0, '', "restarting cluster";

is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "0\n", "soft core size is 0";

# pg_ctl -c, core size=unlimited

is_program_out 'postgres', "pg_ctlcluster $v main restart -- -c", 0, '', "restarting cluster with -c on the command line";

is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "unlimited\n", "soft core size is unlimited";

is ((system "pg_dropcluster $v main --stop"), 0, 'dropping cluster');

check_clean;

# vim: filetype=perl
