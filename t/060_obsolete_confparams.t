# Test upgrading from the oldest version to all majors with all possible
# configuration parameters set. This checks that they are correctly
# transitioned.

use strict;

use lib 't';
use TestLib;

use Test::More;

if (@MAJORS == 1) {
    pass 'only one major version installed, skipping upgrade tests';
    done_testing();
    exit 0;
}

$ENV{_SYSTEMCTL_SKIP_REDIRECT} = 1; # FIXME: testsuite is hanging otherwise

# Test one particular upgrade (old version, new version)
sub do_upgrade {
    my $cur = $_[0];
    my $new = $_[1];
    note "Testing upgrade $cur -> $new";

    # Upgrade cluster
    like_program_out 0, "env LC_MESSAGES=C pg_upgradecluster -v $new $cur main", 0, qr/^Success. Please check/m;
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$new.*online/,
        "New $new cluster is online";
}

# create cluster for oldest version
is_program_out 0, "pg_createcluster $MAJORS[0] main >/dev/null", 0, "";

# generate configuration file with all settings and start cluster
is_program_out 0, "sed -i -e 's/^#\\([a-z]\\)/\\1/' /etc/postgresql/$MAJORS[0]/main/postgresql.conf",
    0, "", "Enabling all settings in /etc/postgresql/$MAJORS[0]/main/postgresql.conf";
like PgCommon::get_conf_value($MAJORS[0], 'main', 'postgresql.conf', 'work_mem'), qr/MB/, "work_mem is set";

# tweak invalid settings
PgCommon::set_conf_value $MAJORS[0], 'main', 'postgresql.conf', 'log_timezone', 'UTC';
PgCommon::set_conf_value $MAJORS[0], 'main', 'postgresql.conf', 'timezone', 'UTC';
PgCommon::disable_conf_value $MAJORS[0], 'main', 'postgresql.conf', 'include', "Disable placeholder value";
# older versions (<= 9.1 as of 2019-03) do not support ssl anymore
my $postgres = PgCommon::get_program_path('postgres', $MAJORS[0]);
my $ldd = `ldd $postgres 2>/dev/null`;
if ($ldd and $ldd !~ /libssl/) {
    is_program_out 0, "sed -i -e 's/^ssl/#ssl/' /etc/postgresql/$MAJORS[0]/main/postgresql.conf",
        0, "", "Disabling ssl settings on server that does not support SSL";
}

# start server
is_program_out 0, "pg_ctlcluster $MAJORS[0] main start", 0, "";

# Loop over all but the latest major version, testing N->N+1 upgrades
for my $index (0 .. @MAJORS - 2) {
    do_upgrade $MAJORS[$index], $MAJORS[$index + 1]
}
# remove all clusters except for the first one
for my $index (1 .. @MAJORS - 1) {
    is_program_out 0, "pg_dropcluster $MAJORS[$index] main --stop", 0, "", "Dropping $MAJORS[$index]/main";
}

# now test a direct upgrade from oldest to newest, to also catch parameters
# which changed several times, like syslog -> redirect_stderr ->
# logging_collector
if ($#MAJORS > 1) {
    is_program_out 0, "pg_ctlcluster $MAJORS[0] main start", 0, "";
    do_upgrade $MAJORS[0], $MAJORS[-1];
    is_program_out 0, "pg_dropcluster $MAJORS[-1] main --stop", 0, "", "Dropping $MAJORS[-1]/main";
} else {
    pass 'only two available versions, skipping tests...';
}

# remove first cluster
is_program_out 0, "pg_dropcluster $MAJORS[0] main --stop", 0, "", "Dropping $MAJORS[0]/main";

check_clean;
done_testing();

# vim: filetype=perl
