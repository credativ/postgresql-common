# Check pg_ctl.conf handling.

use strict; 

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => $MAJORS[-1] >= '8.3' ? 33 : 1;

# Do test with newest version
my $v = $MAJORS[-1];
if ($v < '8.3') {
    pass 'Skipping core limit tests for versions < 8.3';
    exit 0;
}

# enable core dumps
# sudo and salsa-ci set the hard limit to 0 by default, undo that
is_program_out 0, "prlimit --core=0:unlimited --pid=$$", 0, '', "set core file size to unlimited";
is_program_out 'postgres', "sh -c 'ulimit -Hc'", 0, "unlimited\n", "core file size is unlimited";

# create cluster
is ((system "pg_createcluster $v main >/dev/null"), 0, "pg_createcluster $v main");
ok (-f "/etc/postgresql/$v/main/pg_ctl.conf", "/etc/postgresql/$v/main/pg_ctl.conf exists");

# Default behaviour, core size=0
is_program_out 0, "pg_ctlcluster $v main start", 0, '', "starting cluster as root";
is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "0\n", "soft core size is 0";
my $hard_limit = `xargs -i awk '/core/ {print \$6}' /proc/{}/limits < /var/run/postgresql/$v-main.pid`;
chomp $hard_limit;
note "hard core file size limit of root-started postgres process is $hard_limit";

# -c in pg_ctl.conf, core size=unlimited
ok (set_cluster_pg_ctl_conf($v, 'main', '-c'), "set pg_ctl default option to -c");
is_program_out 0, "pg_ctlcluster $v main restart", 0, '', "restarting cluster as root";
is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "$hard_limit\n", "soft core size is $hard_limit";

# Back to default behaviour, core size=0
is_program_out 0, "pg_ctlcluster $v main stop", 0, '', "stopping cluster";
ok (set_cluster_pg_ctl_conf($v, 'main', ''), "restored pg_ctl default option");

# pg_ctl -c, core size=unlimited
is_program_out 'postgres', "pg_ctlcluster $v main start -- -c", 0, '', "starting cluster with -c on the command line as postgres";
is_program_out 'postgres', "xargs -i awk '/core/ {print \$5}' /proc/{}/limits < /var/run/postgresql/$v-main.pid", 0, "unlimited\n", "soft core size is unlimited";
is_program_out 'postgres', "pg_ctlcluster $v main stop", 0, '', "stopping cluster";

is ((system "pg_dropcluster $v main --stop"), 0, 'dropping cluster');
check_clean;

# vim: filetype=perl
