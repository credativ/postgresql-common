# We create a cluster, stop it ungracefully, and check if recovery works.

use strict;

use POSIX qw/dup2/;
use Time::HiRes qw/usleep/;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 19 * ($#MAJORS+1);

sub check_major {
    my $v = $_[0];
    note "Running tests for $v";

    # create cluster
    ok ((system "pg_createcluster $v main --start >/dev/null") == 0,
        "pg_createcluster $v main");

    # try an immediate shutdown and restart
    ok ((system "pg_ctlcluster $v main stop -m i") == 0,
        "pg_ctlcluster $v main stop -m i");
    ok ((system "pg_ctlcluster $v main start") == 0,
        "pg_ctlcluster $v main start");
    ok ((exec_as 'postgres', "psql -c ''") == 0,
        "psql");

    # try again with an write-protected file
    ok ((system "pg_ctlcluster $v main stop -m i") == 0,
        "pg_ctlcluster $v main stop -m i");
    open F, ">/var/lib/postgresql/$v/main/foo";
    print F "moo\n";
    close F;
    ok ((chmod 0444, "/var/lib/postgresql/$v/main/foo"),
        "create write-protected file in data directory");
    ok ((system "pg_ctlcluster $v main start") == 0,
        "pg_ctlcluster $v main start");
    ok ((exec_as 'postgres', "psql -c ''") == 0,
        "psql");

    ok ((system "pg_dropcluster $v main --stop") == 0,
        'pg_dropcluster removes cluster');

    check_clean;
}

foreach (@MAJORS) {
    check_major $_;
}

# vim: filetype=perl
