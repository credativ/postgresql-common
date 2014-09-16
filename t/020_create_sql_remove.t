# We create a cluster, execute some basic SQL commands, drop it again, and
# check that we did not leave anything behind.

use strict; 

use POSIX qw/dup2/;
use Time::HiRes qw/usleep/;

use lib 't';
use TestLib;
use PgCommon;

use Test::More tests => 127 * ($#MAJORS+1);

sub check_major {
    my $v = $_[0];
    note "Running tests for $v";

    # create cluster
    ok ((system "pg_createcluster $v main --start >/dev/null") == 0,
	"pg_createcluster $v main");

    # check that a /var/run/postgresql/ pid file is created
    unless ($PgCommon::rpm) {
        ok_dir '/var/run/postgresql/', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock', "$v-main.pid"], 
            'Socket and pid file are in /var/run/postgresql/';
    } else {
        ok_dir '/var/run/postgresql/', ["$v-main.pid"], 'Pid File is in /tmp';
    }

    # verify that exactly one postmaster is running
    my @pm_pids = pidof (($v >= '8.2') ? 'postgres' : 'postmaster');
    is $#pm_pids, 0, 'Exactly one postmaster process running';

    # check environment
    my %safe_env = qw/LC_ALL 1 LC_CTYPE 1 LANG 1 PWD 1 PGLOCALEDIR 1 PGSYSCONFDIR 1 PG_GRANDPARENT_PID 1 PG_OOM_ADJUST_FILE 1 PG_OOM_ADJUST_VALUE 1 SHLVL 1 PGDATA 1 _ 1/;
    my %env = pid_env $pm_pids[0];
    foreach (keys %env) {
        fail "postmaster has unsafe environment variable $_" unless exists $safe_env{$_};
    }

    # activate external_pid_file
    PgCommon::set_conf_value $v, 'main', 'postgresql.conf', 'external_pid_file', '';

    # add variable to environment file, restart, check if it's there
    open E, ">>/etc/postgresql/$v/main/environment" or 
        die 'could not open environment file for appending';
    print E "PGEXTRAVAR1 = 1 # short one\nPGEXTRAVAR2='foo bar '\n\n# comment";
    close E;
    is_program_out 'postgres', "pg_ctlcluster $v main restart", 0, '',
        'cluster restarts with new environment file';

    @pm_pids = pidof (($v >= '8.2') ? 'postgres' : 'postmaster');
    is $#pm_pids, 0, 'Exactly one postmaster process running';
    %env = pid_env $pm_pids[0];
    is $env{'PGEXTRAVAR1'}, '1', 'correct value of PGEXTRAVAR1 in environment';
    is $env{'PGEXTRAVAR2'}, 'foo bar ', 'correct value of PGEXTRAVAR2 in environment';

    # Now there should not be an external PID file any more, since we set it
    # explicitly
    unless ($PgCommon::rpm) {
        ok_dir '/var/run/postgresql', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], 
            'Socket, but not PID file in /var/run/postgresql/';
    } else {
        ok_dir '/var/run/postgresql', [], '/var/run/postgresql/ is empty';
    }

    # verify that the correct client version is selected
    like_program_out 'postgres', 'createdb --version', 0, qr/^createdb \(PostgreSQL\) $v/,
        'pg_wrapper selects version number of cluster';

    # we always want to use the latest version of "psql", though.
    like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $ALL_MAJORS[-1]/,
        'pg_wrapper selects version number of cluster';

    my $default_log = "/var/log/postgresql/postgresql-$v-main.log";

    # verify that the cluster is displayed
    my $ls = `pg_lsclusters -h`;
    $ls =~ s/\s+/ /g;
    $ls =~ s/\s*$//;
    is $ls, "$v main 5432 online postgres /var/lib/postgresql/$v/main $default_log",
	'pg_lscluster reports online cluster on port 5432';

    # verify that the log file is actually used
    ok !-z $default_log, 'log file is actually used';

    # verify configuration file permissions
    my $postgres_uid = (getpwnam 'postgres')[2];
    my @st = stat "/etc/postgresql/$v";
    is $st[4], $postgres_uid, 'version configuration directory file is owned by user "postgres"';
    my @st = stat "/etc/postgresql/$v/main";
    is $st[4], $postgres_uid, 'configuration directory file is owned by user "postgres"';

    # verify data file permissions
    my @st = stat "/var/lib/postgresql/$v";
    is $st[4], $postgres_uid, 'version data directory file is owned by user "postgres"';
    my @st = stat "/var/lib/postgresql/$v/main";
    is $st[4], $postgres_uid, 'data directory file is owned by user "postgres"';

    # verify log file permissions
    my @logstat = stat $default_log;
    is $logstat[2], 0100640, 'log file has 0640 permissions';
    is $logstat[4], $postgres_uid, 'log file is owned by user "postgres"';
    is $logstat[5], (getgrnam 'adm')[2], 'log file is owned by group "adm"';

    # check default log file configuration; when not specifying -l with
    # pg_createcluster, we should not have a 'log' symlink
    ok !-e "/etc/postgresql/$v/main/log", 'no log symlink by default';
    ok !-z $default_log, "$default_log is the default log if log symlink is missing";
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/^$v\s+main.*$default_log\n$/;
 
    # verify that log symlink works
    is ((exec_as 'root', "pg_ctlcluster $v main stop"), 0, 'stopping cluster');
    open L, ">$default_log"; close L; # empty default log file
    my $p = (PgCommon::cluster_data_directory $v, 'main') . '/mylog';
    symlink $p, "/etc/postgresql/$v/main/log";
    is ((exec_as 'root', "pg_ctlcluster $v main start"), 0, 
        'restarting cluster with nondefault log symlink');
    ok !-z $p, "log target is used as log file";
    ok -z $default_log, "default log is not used";
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/^$v\s+main.*$p\n$/;
    is ((exec_as 'root', "pg_ctlcluster $v main stop"), 0, 'stopping cluster');
    open L, ">$p"; close L; # empty log file

    # verify that explicitly configured log file trumps log symlink
    PgCommon::set_conf_value ($v, 'main', 'postgresql.conf', 
        ($v >= '8.3' ? 'logging_collector' : 'redirect_stderr'), 'on');
    PgCommon::set_conf_value $v, 'main', 'postgresql.conf', 'log_filename', "$v#main.log";
    is ((exec_as 'root', "pg_ctlcluster $v main start"), 0, 
        'restarting cluster with explicitly configured log file');
    ok -z $default_log, "default log is not used";
    ok -z $p, "log symlink target is not used";
    my @l = glob ((PgCommon::cluster_data_directory $v, 'main') .  "/pg_log/$v#main.log*");
    is $#l, 0, 'exactly one log file';
    ok (-e $l[0] && ! -z $l[0], 'custom log is actually used');
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/^$v\s+main.*$v#main.log\n$/;

    # clean up
    PgCommon::disable_conf_value ($v, 'main', 'postgresql.conf', 
        ($v >= '8.3' ? 'logging_collector' : 'redirect_stderr'), '');
    PgCommon::disable_conf_value $v, 'main', 'postgresql.conf', 'log_filename', '';
    unlink "/etc/postgresql/$v/main/log";

    # verify that the postmaster does not have an associated terminal
    unlike_program_out 0, 'ps -o tty -U postgres h', 0, qr/tty|pts/,
        'postmaster processes do not have an associated terminal';

    # verify that SSL is enabled (which should work for user postgres in a
    # default installation)
    my $ssl = config_bool (PgCommon::get_conf_value $v, 'main', 'postgresql.conf', 'ssl');
    if ($PgCommon::rpm) {
        is $ssl, undef, 'SSL is disabled';
    } else {
        is $ssl, 1, 'SSL is enabled';
    }

    # Create user nobody, a database 'nobodydb' for him, check the database list
    my $outref;
    is ((exec_as 'nobody', 'psql -l 2>/dev/null', $outref), 2, 'psql -l fails for nobody');
    is ((exec_as 'postgres', 'createuser nobody -D -R -S'), 0, 'createuser nobody');
    is ((exec_as 'postgres', 'createdb -O nobody nobodydb'), 0, 'createdb nobodydb');
    is ((exec_as 'nobody', 'psql -ltA|grep "|" | cut -f1-3 -d"|"', $outref), 0, 'psql -ltA succeeds for nobody');
    is ($$outref, 'nobodydb|nobody|UTF8
postgres|postgres|UTF8
template0|postgres|UTF8
template1|postgres|UTF8
', 'psql -ltA output');

    # Then fill nobodydb with some data.
    is ((exec_as 'nobody', 'psql nobodydb -c "create table phone (name varchar(255) PRIMARY KEY, tel int NOT NULL)" 2>/dev/null'), 
	0, 'SQL command: create table');
    is ((exec_as 'nobody', 'psql nobodydb -c "insert into phone values (\'Bob\', 1)"'), 0, 'SQL command: insert into table values');
    is ((exec_as 'nobody', 'psql nobodydb -c "insert into phone values (\'Alice\', 2)"'), 0, 'SQL command: insert into table values');
    is ((exec_as 'nobody', 'psql nobodydb -c "insert into phone values (\'Bob\', 3)"'), 1, 'primary key violation');

    # Check table contents
    is_program_out 'nobody', 'psql -tAc "select * from phone order by name" nobodydb', 0,
        'Alice|2
Bob|1
', 'SQL command output: select -tA';
    is_program_out 'nobody', 'psql -txc "select * from phone where name = \'Alice\'" nobodydb', 0,
        'name | Alice
tel  | 2

', 'SQL command output: select -tx';
    is_program_out 'nobody', 'psql -tAxc "select * from phone where name = \'Alice\'" nobodydb', 0,
        'name|Alice
tel|2
', 'SQL command output: select -tAx';

    # Check PL/Perl untrusted
    my $fn_cmd = 'CREATE FUNCTION read_file() RETURNS text AS \'open F, \\"/etc/passwd\\"; \\$buf = <F>; close F; return \\$buf;\' LANGUAGE plperl';
    is ((exec_as 'nobody', 'createlang plperlu nobodydb'), 1, 'createlang plperlu fails for user nobody');
    is_program_out 'postgres', 'createlang plperlu nobodydb', 0, '', 'createlang plperlu succeeds for user postgres';
    is ((exec_as 'nobody', "psql nobodydb -qc \"${fn_cmd}u;\""), 1, 'creating PL/PerlU function as user nobody fails');
    is ((exec_as 'postgres', "psql nobodydb -qc \"${fn_cmd};\""), 1, 'creating unsafe PL/Perl function as user postgres fails');
    is_program_out 'postgres', "psql nobodydb -qc \"${fn_cmd}u;\"", 0, '', 'creating PL/PerlU function as user postgres succeeds';
    like_program_out 'nobody', 'psql nobodydb -Atc "select read_file()"',
	0, qr/^root:/, 'calling PL/PerlU function';

    # Check PL/Perl trusted
    my $pluser = ($v >= '8.3') ? 'nobody' : 'postgres'; # pg_pltemplate allows non-superusers to install trusted languages in 8.3+
    is_program_out $pluser, 'createlang plperl nobodydb', 0, '', "createlang plperl succeeds for user $pluser";
    is ((exec_as 'nobody', "psql nobodydb -qc \"${fn_cmd};\""), 1, 'creating unsafe PL/Perl function as user nobody fails');
    is_program_out 'nobody', 'psql nobodydb -qc "CREATE FUNCTION remove_vowels(text) RETURNS text AS \'\\$_[0] =~ s/[aeiou]/_/ig; return \\$_[0];\' LANGUAGE plperl;"',
	0, '', 'creating PL/Perl function as user nobody succeeds';
    is_program_out 'nobody', 'psql nobodydb -Atc "select remove_vowels(\'foobArish\')"',
	0, "f__b_r_sh\n", 'calling PL/Perl function';

    # Check PL/Python (untrusted)
    is_program_out 'postgres', 'createlang plpythonu nobodydb', 0, '', 'createlang plpythonu succeeds for user postgres';
    is_program_out 'postgres', 'psql nobodydb -qc "CREATE FUNCTION capitalize(text) RETURNS text AS \'import sys; return args[0].capitalize() + sys.version[0]\' LANGUAGE plpythonu;"',
	0, '', 'creating PL/Python function as user postgres succeeds';
    is_program_out 'nobody', 'psql nobodydb -Atc "select capitalize(\'foo\')"',
	0, "Foo2\n", 'calling PL/Python function';

    # Check PL/Python3 (untrusted)
    if ($v >= '9.1' and not $PgCommon::rpm) {
	is_program_out 'postgres', 'createlang plpython3u nobodydb', 0, '', 'createlang plpython3u succeeds for user postgres';
	is_program_out 'postgres', 'psql nobodydb -qc "CREATE FUNCTION capitalize3(text) RETURNS text AS \'import sys; return args[0].capitalize() + sys.version[0]\' LANGUAGE plpython3u;"',
	    0, '', 'creating PL/Python3 function as user postgres succeeds';
	is_program_out 'nobody', 'psql nobodydb -Atc "select capitalize3(\'foo\')"',
	    0, "Foo3\n", 'calling PL/Python function';
    } else {
	pass "Skipping PL/Python3 test for version $v...";
	pass '...';
	pass '...';
	pass '...';
	pass '...';
	pass '...';
    }

    # Check PL/Tcl (trusted/untrusted)
    is_program_out 'postgres', 'createlang pltcl nobodydb', 0, '', 'createlang pltcl succeeds for user postgres';
    is_program_out 'postgres', 'createlang pltclu nobodydb', 0, '', 'createlang pltclu succeeds for user postgres';
    is_program_out 'nobody', 'psql nobodydb -qc "CREATE FUNCTION tcl_max(integer, integer) RETURNS integer AS \'if {\\$1 > \\$2} {return \\$1}; return \\$2\' LANGUAGE pltcl STRICT;"',
	0, '', 'creating PL/Tcl function as user nobody succeeds';
    is_program_out 'postgres', 'psql nobodydb -qc "CREATE FUNCTION tcl_max_u(integer, integer) RETURNS integer AS \'if {\\$1 > \\$2} {return \\$1}; return \\$2\' LANGUAGE pltclu STRICT;"',
	0, '', 'creating PL/TclU function as user postgres succeeds';
    is_program_out 'nobody', 'psql nobodydb -Atc "select tcl_max(3,4)"', 0,
        "4\n", 'calling PL/Tcl function';
    is_program_out 'nobody', 'psql nobodydb -Atc "select tcl_max_u(5,4)"', 0,
        "5\n", 'calling PL/TclU function';

    # fake rotated logs to check that they are cleaned up properly
    open L, ">$default_log.1" or die "could not open fake rotated log file";
    print L "old log .1\n";
    close L;
    open L, ">$default_log.2" or die "could not open fake rotated log file";
    print L "old log .2\n";
    close L;
    if (system "gzip -9 $default_log.2") {
        die "could not gzip fake rotated log";
    }

    # Check that old-style pgdata symbolic link still works (p-common 0.90+
    # does not create them any more, but they still need to work for existing
    # installations)
    is ((exec_as 'root', "pg_ctlcluster $v main stop"), 0, 'stopping cluster');
    my $datadir = PgCommon::get_conf_value $v, 'main', 'postgresql.conf', 'data_directory';
    symlink $datadir, "/etc/postgresql/$v/main/pgdata";

    # data_directory should trump the pgdata symlink
    PgCommon::set_conf_value $v, 'main', 'postgresql.conf', 'data_directory', '/nonexisting';
    like_program_out 0, "pg_ctlcluster $v main start", 1, 
        qr/\/nonexisting is not accessible/,
        'cluster fails to start with invalid data_directory and valid pgdata symlink';

    # if only pgdata symlink is present, it is authoritative
    PgCommon::disable_conf_value $v, 'main', 'postgresql.conf', 'data_directory', 'disabled for test';
    is_program_out 0, "pg_ctlcluster $v main start", 0, '',
        'cluster restarts with pgdata symlink';

    # check properties of backend processes
    pipe RH, WH;
    my $psql = fork;
    if (!$psql) {
	close WH;
	my @pw = getpwnam 'nobody';
	change_ugid $pw[2], $pw[3];
	open(STDIN, "<& RH");
	dup2(POSIX::open('/dev/null', POSIX::O_WRONLY), 1);
	exec 'psql', 'nobodydb' or die "could not exec psql process: $!";
    }
    close RH;
    select WH; $| = 1; # make unbuffered

    my $master_pid = `ps --user postgres hu | grep 'bin/postgres.*-D' | grep -v grep | awk '{print \$2}'`;
    chomp $master_pid;

    my $client_pid;
    while (!$client_pid) {
	usleep $delay;
	$client_pid = `ps --user postgres hu | grep 'postgres: nobody nobodydb' | grep -v grep | awk '{print \$2}'`;
	($client_pid) = ($client_pid =~ /(\d+)/); # untaint
    }

    # OOM score adjustment under Linux: postmaster gets bigger shields for >=
    # 9.1, but client backends stay at default
    my $adj;
    open F, "/proc/$master_pid/oom_score_adj";
    $adj = <F>;
    chomp $adj;
    close F;
    if ($v >= '9.1' and not $PgCommon::rpm) {
        cmp_ok $adj, '<=', -500, 'postgres master has OOM killer protection';
    } else {
        is $adj, 0, 'postgres master has no OOM adjustment';
    }

    open F, "/proc/$client_pid/oom_score_adj";
    $adj = <F>;
    chomp $adj;
    close F;
    is $adj, 0, 'postgres client backend has no OOM adjustment';

    # test process title update
    like_program_out 0, "ps h $client_pid", 0, qr/ idle\s*$/, 'process title is idle';
    print WH "BEGIN;\n";
    usleep $delay;
    like_program_out 0, "ps h $client_pid", 0, qr/idle in transaction/, 'process title is idle in transaction';
    print WH "SELECT pg_sleep(1);\n";
    usleep $delay;
    like_program_out 0, "ps h $client_pid", 0, qr/SELECT/, 'process title is SELECT';

    close WH;
    waitpid $psql, 0;

    # Drop database and user again.
    usleep $delay;
    is ((exec_as 'nobody', 'dropdb nobodydb', $outref, 0), 0, 'dropdb nobodydb', );
    is ((exec_as 'postgres', 'dropuser nobody', $outref, 0), 0, 'dropuser nobody');

    # log file gets re-created by pg_ctlcluster
    is ((exec_as 'postgres', "pg_ctlcluster $v main stop"), 0, 'stopping cluster');
    unlink $default_log;
    is ((exec_as 'postgres', "pg_ctlcluster $v main start"), 0, 'starting cluster as postgres works without a log file');
    ok (-e $default_log && ! -z $default_log, 'log file got recreated and used');

    # stop server, clean up, check for leftovers
    ok ((system "pg_dropcluster $v main --stop") == 0, 
	'pg_dropcluster removes cluster');

    check_clean;
}

foreach (@MAJORS) { 
    check_major $_;
}

# vim: filetype=perl
