# We create a cluster, stop it ungracefully, and check if recovery works.

use strict;

use POSIX qw/dup2/;
use Time::HiRes qw/usleep/;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 17 * @MAJORS;

sub check_major {
    my $v = $_[0];
    note "Running tests for $v";

    # create cluster
    program_ok (0, "pg_createcluster $v main --start >/dev/null");

    # try an immediate shutdown and restart
    program_ok (0, "pg_ctlcluster $v main stop -m i");
    program_ok (0, "pg_ctlcluster $v main start");
    my $c = 0; # fallback for when pg_isready is missing (PG < 9.3)
    while (system ("pg_isready -q 2>&1") >> 8 == 1 and $c++ < 15) {
        sleep(1);
    }
    program_ok ('postgres', "psql -c ''");

    # try again with an write-protected file
    program_ok (0, "pg_ctlcluster $v main stop -m i");
    open F, ">/var/lib/postgresql/$v/main/foo";
    print F "moo\n";
    close F;
    ok ((chmod 0444, "/var/lib/postgresql/$v/main/foo"),
        "create write-protected file in data directory");
    program_ok (0, "pg_ctlcluster $v main start");
    $c = 0;
    while (system ("pg_isready -q 2>&1") >> 8 == 1 and $c++ < 15) {
        sleep(1);
    }
    program_ok ('postgres', "psql -c ''");

    program_ok (0, "pg_dropcluster $v main --stop", 0,
        'pg_dropcluster removes cluster');

    check_clean;
}

foreach (@MAJORS) {
    check_major $_;
}

# vim: filetype=perl
