use strict;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 71 * @MAJORS;

my $systemd = (-d "/run/systemd/system" and not $ENV{_SYSTEMCTL_SKIP_REDIRECT});
note $systemd ? "We are running systemd" : "We are not running systemd";

# check cluster status
# arguments: <version> <pg_ctlcluster exit status> <systemctl exit status> <text to print>
sub check_status {
    my ($v, $ctlstatus, $scstatus, $text) = @_;
    program_ok (0, "pg_ctlcluster $v main status", $ctlstatus, "cluster $v main $text");
    if ($systemd) {
        program_ok (0, "systemctl status postgresql\@$v-main", $scstatus, "service postgresql\@$v-main $text");
    } else {
        pass '';
    }
}

sub check_major {
    my $v = $_[0];
    my $ctlstopped = $v >= 9.2 ? 3 : 1; # pg_ctl status "not running" changed in 9.2
    note "Running tests for $v";

    note "Cluster does not exist yet"; ###############################
    check_status $v, 1, 3, "does not exist";

    # try to start postgresql
    if ($systemd) {
        program_ok (0, "systemctl start postgresql");
    } else {
        program_ok (0, "/etc/init.d/postgresql start");
    }
    check_status $v, 1, 3, "does not exist";

    # try to start specific cluster
    if ($systemd) {
        program_ok (0, "systemctl start postgresql\@$v-main", 1);
    } else {
        program_ok (0, "/etc/init.d/postgresql start $v");
    }
    check_status $v, 1, 3, "does not exist";

    note "Start/stop postgresql using system tools"; ###############################

    # create cluster
    program_ok (0, "pg_createcluster $v main");
    check_status $v, $ctlstopped, 3, "is stopped";

    # start postgresql
    if ($systemd) {
        program_ok (0, "systemctl start postgresql");
    } else {
        program_ok (0, "/etc/init.d/postgresql start");
    }
    check_status $v, 0, 0, "is running";

    # start postgresql again
    if ($systemd) {
        program_ok (0, "systemctl start postgresql");
    } else {
        program_ok (0, "/etc/init.d/postgresql start");
    }
    check_status $v, 0, 0, "is already running";

    # stop postgresql
    if ($systemd) {
        program_ok (0, "systemctl stop postgresql");
        sleep 6; # FIXME: systemctl stop postgresql is not yet synchronous (#759725)
    } else {
        program_ok (0, "/etc/init.d/postgresql stop");
    }
    check_status $v, $ctlstopped, 3, "is stopped";

    # stop postgresql again
    if ($systemd) {
        program_ok (0, "systemctl stop postgresql");
    } else {
        program_ok (0, "/etc/init.d/postgresql stop");
    }
    check_status $v, $ctlstopped, 3, "is already stopped";

    note "Start/stop specific cluster using system tools"; ###############################

    # start cluster using system tools
    if ($systemd) {
        program_ok (0, "systemctl start postgresql\@$v-main");
    } else {
        program_ok (0, "/etc/init.d/postgresql start $v");
    }
    check_status $v, 0, 0, "is running";

    # try start cluster again
    if ($systemd) {
        program_ok (0, "systemctl start postgresql\@$v-main");
    } else {
        program_ok (0, "/etc/init.d/postgresql start $v");
    }
    check_status $v, 0, 0, "is running";

    # restart cluster
    if ($systemd) {
        program_ok (0, "systemctl restart postgresql\@$v-main");
    } else {
        program_ok (0, "/etc/init.d/postgresql restart $v");
    }
    check_status $v, 0, 0, "is running";

    # stop cluster
    if ($systemd) {
        program_ok (0, "systemctl stop postgresql\@$v-main");
    } else {
        program_ok (0, "/etc/init.d/postgresql stop $v");
    }
    check_status $v, $ctlstopped, 3, "is stopped";

    # try to stop cluster again
    if ($systemd) {
        program_ok (0, "systemctl stop postgresql\@$v-main");
    } else {
        program_ok (0, "/etc/init.d/postgresql stop $v");
    }
    check_status $v, $ctlstopped, 3, "is already stopped";

    # drop cluster
    program_ok (0, "pg_dropcluster $v main");
    check_status $v, 1, 3, "does not exist";

    note "Start/stop specific cluster using pg_*cluster"; ###############################

    # try to start cluster
    program_ok (0, "pg_ctlcluster start $v main", 1); # syntax variation: action version cluster
    check_status $v, 1, 3, "does not exist";

    # create cluster and start it
    program_ok (0, "pg_createcluster $v main --start");
    check_status $v, 0, 0, "is running";

    # try to start cluster again
    my $exitagain = $systemd ? 0 : 2;
    program_ok (0, "pg_ctlcluster $v main start", $exitagain);
    check_status $v, 0, 0, "is already running";

    # restart cluster
    program_ok (0, "pg_ctlcluster $v-main restart"); # syntax variation: version-cluster action
    check_status $v, 0, 0, "is running";

    # stop cluster
    program_ok (0, "pg_ctlcluster $v main stop");
    check_status $v, $ctlstopped, 3, "is stopped";

    # try to stop cluster again
    program_ok (0, "pg_ctlcluster $v main stop", 2);
    check_status $v, $ctlstopped, 3, "is already stopped";

    # start cluster
    program_ok (0, "pg_ctlcluster start $v-main"); # syntax variation: action version-cluster
    check_status $v, 0, 0, "is running";

    # stop server, clean up, check for leftovers
    program_ok (0, "pg_dropcluster $v main --stop");

    check_clean;
}

foreach (@MAJORS) {
    check_major $_;
}

# vim: filetype=perl
