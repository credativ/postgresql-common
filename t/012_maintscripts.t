use strict;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => $PgCommon::rpm ? 1 : 14;

if ($PgCommon::rpm) {
    pass 'No maintainer script tests on rpm';
    exit;
}

my $v = $MAJORS[-1];

# create cluster
program_ok 0, "pg_createcluster $v main --start";

# get postmaster PID
my $postmaster_pid = `head -1 /var/lib/postgresql/$v/main/postmaster.pid`;
chomp $postmaster_pid;
ok $postmaster_pid > 0, "postmaster PID is $postmaster_pid";

# "upgrade" postgresql-common to check if postgresql.service is left alone
program_ok 0, 'dpkg-reconfigure --frontend=noninteractive postgresql-common', 0, '';
program_ok 0, "ps -ho pid $postmaster_pid", 0, "postmaster $postmaster_pid was not restarted";

# stop server, clean up, check for leftovers
program_ok 0, "pg_dropcluster $v main --stop";

check_clean;

# vim: filetype=perl
