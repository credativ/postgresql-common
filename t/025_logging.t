# Test various logging-related things

use strict;

use lib 't';
use TestLib;
use PgCommon;
use Time::HiRes qw/usleep/;

use Test::More tests => 55 * @MAJORS;

my $syslog_works = 0;

sub check_logging ($$)
{
    my ($text, $msg) = @_;
    my $ls = `pg_lsclusters -h`;
    $ls =~ s/\s+/ /g;
    $ls =~ s/\s*$//;
    like $ls, $text, $msg;
}

sub check_major {
    my $v = $_[0];
    note "Running tests for $v";
    my $pgdata = "/var/lib/postgresql/$v/main";

    # create cluster
    ok ((system "pg_createcluster $v main --start >/dev/null") == 0,
        "pg_createcluster $v main");

    # default log setup
    my $default_log = "/var/log/postgresql/postgresql-$v-main.log";
    check_logging qr($v main 5432 online postgres $pgdata $default_log), "pg_lscluster reports logfile $default_log";
    like_program_out 'postgres', "psql -qc \"'foobar_${v}_$$'\"", 1, qr/syntax error.*foobar_${v}_$$/, 'log an error';
    like_program_out 'postgres', "grep --binary-files=text foobar_${v}_$$ $default_log", 0, qr/syntax error.*foobar_${v}_$$/, 'error appears in logfile';

    # syslog
    is_program_out 0, "pg_conftool $v main set log_destination syslog", 0, "", "set log_destination syslog";
    is_program_out 0, "pg_ctlcluster $v main reload", 0, "", "$v main reload";
    is_program_out 'postgres', "psql -Atc \"show log_destination\"", 0, "syslog\n", 'log_destination is syslog';
    check_logging qr($v main 5432 online postgres $pgdata syslog), "pg_lscluster reports syslog";
    SKIP: {
        skip "/var/log/syslog not available", 2 unless ($syslog_works);
        usleep $delay;
        like_program_out 0, "grep --binary-files=text 'postgres.*parameter \"log_destination\" changed to \"syslog\"' /var/log/syslog", 0, qr/log_destination/, 'error appears in /var/log/syslog';
    }

    # turn logging_collector on, csvlog
    my $pg_log = $v >= 10 ? 'log' : 'pg_log'; # log directory in PGDATA changed in PG 10
    SKIP: {
        skip "No logging collector in 8.2", 30 if ($v <= 8.2);
    is_program_out 0, "pg_conftool $v main set logging_collector on", 0, "", "set logging_collector on";
    is_program_out 0, "pg_conftool $v main set log_destination csvlog", 0, "", "set log_destination csvlog";
    is_program_out 0, "pg_ctlcluster $v main restart", 0, "", "$v main restart";
    is_program_out 'postgres', "psql -Atc \"show logging_collector\"", 0, "on\n", 'logging_collector is on';
    is_program_out 'postgres', "psql -Atc \"show log_destination\"", 0, "csvlog\n", 'log_destination is csvlog';
    check_logging qr($v main 5432 online postgres $pgdata $pg_log/.*\.csv), "pg_lscluster reports csvlog";
    like_program_out 'postgres', "psql -qc \"'barbaz_${v}_$$'\"", 1, qr/syntax error.*barbaz_${v}_$$/, 'log an error';
    like_program_out 'postgres', "grep --binary-files=text barbaz_${v}_$$ $pgdata/$pg_log/*.csv", 0, qr/syntax error.*barbaz_${v}_$$/, "error appears in $pg_log/*.csv";

    # stderr,syslog,csvlog
    is_program_out 0, "pg_conftool $v main set log_destination stderr,syslog,csvlog", 0, "", "set log_destination stderr,syslog,csvlog";
    is_program_out 0, "pg_ctlcluster $v main reload", 0, "", "$v main reload";
    is_program_out 'postgres', "psql -Atc \"show log_destination\"", 0, "stderr,syslog,csvlog\n", 'log_destination is stderr,syslog,csvlog';
    check_logging qr($v main 5432 online postgres $pgdata $pg_log/.*\.log,syslog,$pg_log/.*\.csv), "pg_lscluster reports stderr,syslog,csvlog";
    like_program_out 'postgres', "psql -qc \"'moo_${v}_$$'\"", 1, qr/syntax error.*moo_${v}_$$/, 'log an error';
    like_program_out 'postgres', "grep --binary-files=text moo_${v}_$$ $pgdata/$pg_log/*.log", 0, qr/syntax error.*moo_${v}_$$/, "error appears in $pg_log/*.log";
    SKIP: {
        skip "/var/log/syslog not available", 2 unless ($syslog_works);
        usleep $delay;
        like_program_out 0, "grep --binary-files=text 'postgres.*moo_${v}_$$' /var/log/syslog", 0, qr/moo_${v}_$$/, 'error appears in /var/log/syslog';
    }
    like_program_out 'postgres', "grep --binary-files=text moo_${v}_$$ $pgdata/$pg_log/*.csv", 0, qr/syntax error.*moo_${v}_$$/, "error appears in $pg_log/*.csv";
    }

    # stop server, clean up, check for leftovers
    is_program_out 0, "pg_dropcluster $v main --stop", 0, "", 'pg_dropcluster removes cluster';

    check_clean;
}

system "logger -t '$0' 'test-logging-$$'";
usleep $delay;
if (system ("grep --binary-files=text -q 'test-logging-$$' /var/log/syslog 2> /dev/null") == 0) {
    note 'Logging to /var/log/syslog works';
    $syslog_works = 1;
} else {
    note 'Logging to /var/log/syslog does not work, skipping some syslog tests';
}

foreach (@MAJORS) {
    check_major $_;
}

# vim: filetype=perl
