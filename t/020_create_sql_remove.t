# We create a cluster, execute some basic SQL commands, drop it again, and
# check that we did not leave anything behind.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 76 * ($#MAJORS+1);


sub check_major {
    my $v = $_[0];

    # create cluster
    ok ((system "pg_createcluster $v main --start >/dev/null") == 0,
	"pg_createcluster $v main");

    # check that a /var/run/postgresql/ pid file is created for 8.0+
    if ($v ge '8.0') {
	ok_dir '/var/run/postgresql/', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock', "$v-main.pid"], 
	    'Socket and pid file are in /var/run/postgresql/';
    } else {
	ok_dir '/var/run/postgresql', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], 
	    'Socket is in /var/run/postgresql/';
    }

    # verify that pg_autovacuum is running if it is available
    my $pg_autovacuum = get_program_path 'pg_autovacuum', $v;

    if ($pg_autovacuum) {
	like ((ps 'pg_autovacuum'), qr/$pg_autovacuum/, 'pg_autovacuum is running');
    } else {
	is ((ps 'pg_autovacuum'), '', "No pg_autovacuum available for version $v");
    }

    # verify that exactly one postmaster is running
    my @pm_pids = pidof (($v ge '8.2') ? 'postgres' : 'postmaster');
    is $#pm_pids, 0, 'Exactly one postmaster process running';

    # check environment
    my %safe_env = qw/LC_ALL 1 LC_CTYPE 1 LANG 1 PWD 1 PGLOCALEDIR 1 PGSYSCONFDIR 1 SHLVL 1 PGDATA 1 _ 1/;
    my %env = pid_env $pm_pids[0];
    foreach (keys %env) {
        fail "postmaster has unsafe environment variable $_" unless exists $safe_env{$_};
    }

    # activate external_pid_file for 8.0+
    if ($v ge '8.0') {
	PgCommon::set_conf_value $v, 'main', 'postgresql.conf', 'external_pid_file', '';
    }

    # add variable to environment file, restart, check if it's there
    open E, ">>/etc/postgresql/$v/main/environment" or 
        die 'could not open environment file for appending';
    print E "PGEXTRAVAR1 = 1 # short one\nPGEXTRAVAR2='foo bar '\n\n# comment";
    close E;
    is_program_out 'postgres', "pg_ctlcluster $v main restart", 0, '',
        'cluster restarts with new environment file';

    @pm_pids = pidof (($v ge '8.2') ? 'postgres' : 'postmaster');
    is $#pm_pids, 0, 'Exactly one postmaster process running';
    %env = pid_env $pm_pids[0];
    is $env{'PGEXTRAVAR1'}, '1', 'correct value of PGEXTRAVAR1 in environment';
    is $env{'PGEXTRAVAR2'}, 'foo bar ', 'correct value of PGEXTRAVAR2 in environment';

    # Now there should not be an external PID file any more, since we set it
    # explicitly
    ok_dir '/var/run/postgresql', ['.s.PGSQL.5432', '.s.PGSQL.5432.lock'], 
	'Socket, but not PID file in /var/run/postgresql/';

    # verify that the correct client version is selected
    like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $v/,
        'pg_wrapper selects version number of cluster';

    # verify that the cluster is displayed
    my $ls = `pg_lsclusters -h`;
    $ls =~ s/\s*$//;
    is $ls, "$v     main      5432 online postgres /var/lib/postgresql/$v/main       /var/log/postgresql/postgresql-$v-main.log",
	'pg_lscluster reports online cluster on port 5432';

    # verify that the log file is actually used
    ok !-z "/var/log/postgresql/postgresql-$v-main.log", 'log file is actually used';

    # verify that the postmaster does not have an associated terminal
    unlike_program_out 0, 'ps -o tty -U postgres h', 0, qr/tty|pts/,
        'postmaster processes do not have an associated terminal';

    # verify that SSL is enabled (which should work for user postgres in a
    # default installation)
    if ($v ge '8.0') {
        my $ssl = config_bool (PgCommon::get_conf_value $v, 'main', 'postgresql.conf', 'ssl');
        is $ssl, 1, 'SSL is enabled';
    } else {
        pass 'Skipping SSL test for versions before 8.0';
    }

    # Create user nobody, a database 'nobodydb' for him, check the database list
    my $outref;
    is ((exec_as 'nobody', 'psql -l 2>/dev/null', $outref), 2, 'psql -l fails for nobody');
    is ((exec_as 'postgres', 'createuser nobody -D ' . (($v ge '8.1') ? '-R -s' : '-A')), 0, 'createuser nobody');
    is ((exec_as 'postgres', 'createdb -O nobody nobodydb'), 0, 'createdb nobodydb');
    is ((exec_as 'nobody', 'psql -ltA', $outref), 0, 'psql -ltA succeeds for nobody');
    if ($v ge '8.1') {
	is ($$outref, 'nobodydb|nobody|UTF8
postgres|postgres|UTF8
template0|postgres|UTF8
template1|postgres|UTF8
', 'psql -ltA output');
    } else {
	is ($$outref, 'nobodydb|nobody|UNICODE
template0|postgres|UNICODE
template1|postgres|UNICODE
', 'psql -ltA output');
}

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
', 'SQL command output: select';

    # Check PL/Perl (trusted/untrusted)
    is_program_out 'postgres', 'createlang plperl nobodydb', 0, '', 'createlang plperl succeeds for user postgres';
    is_program_out 'postgres', 'createlang plperlu nobodydb', 0, '', 'createlang plperlu succeeds for user postgres';
    is_program_out 'nobody', 'psql nobodydb -qc "CREATE FUNCTION remove_vowels(text) RETURNS text AS \'\\$_[0] =~ s/[aeiou]/_/ig; return \\$_[0];\' LANGUAGE plperl;"',
	0, '', 'creating PL/Perl function as user nobody succeeds';
    is_program_out 'nobody', 'psql nobodydb -Atc "select remove_vowels(\'foobArish\')"',
	0, "f__b_r_sh\n", 'calling PL/Perl function';

    # Check PL/Python (untrusted)
    is_program_out 'postgres', 'createlang plpythonu nobodydb', 0, '', 'createlang plpythonu succeeds for user postgres';
    is_program_out 'postgres', 'psql nobodydb -qc "CREATE FUNCTION capitalize(text) RETURNS text AS \'return args[0].capitalize()\' LANGUAGE plpythonu;"',
	0, '', 'creating PL/Python function as user postgres succeeds';
    is_program_out 'nobody', 'psql nobodydb -Atc "select capitalize(\'foo\')"',
	0, "Foo\n", 'calling PL/Python function';

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

    # Check pg_maintenance
    if ($pg_autovacuum || $v ge '8.1') {
        like_program_out 0, 'pg_maintenance', 0, qr/^Skipping.*\n$/, 'pg_maintenance skips autovacuumed cluster';
    } else {
        like_program_out 0, 'pg_maintenance', 0, qr/^Doing.*\n$/, 'pg_maintenance handles non-autovacuumed cluster';
    }
    like_program_out 0, 'pg_maintenance --force', 0, qr/^Doing.*\n$/, 
        'pg_maintenance --force always handles cluster';

    # fake rotated logs to check that they are cleaned up properly
    open L, ">/var/log/postgresql/postgresql-$v-main.log.1" or
        die "could not open fake rotated log file";
    print L "old log .1\n";
    close L;
    open L, ">/var/log/postgresql/postgresql-$v-main.log.2" or
        die "could not open fake rotated log file";
    print L "old log .2\n";
    close L;
    if (system "gzip -9 /var/log/postgresql/postgresql-$v-main.log.2") {
        die "could not gzip fake rotated log";
    }

    # Check that old-style pgdata symbolic link still works (p-common 0.90+
    # does not create them any more for >= 8.0 clusters, but they still need to
    # work for existing installations)
    if ($v ge '8.0') {
        is ((exec_as 0, "pg_ctlcluster $v main stop"), 0, 'stopping cluster');
        my $datadir = PgCommon::get_conf_value $v, 'main', 'postgresql.conf', 'data_directory';
        symlink $datadir, "/etc/postgresql/$v/main/pgdata";

        # data_directory should trump the pgdata symlink
        PgCommon::set_conf_value $v, 'main', 'postgresql.conf', 'data_directory', '/nonexisting';
        like_program_out 0, "pg_ctlcluster $v main start", 1, 
            qr/could not open file.*\/nonexisting/,
            'cluster fails to start with invalid data_directory and valid pgdata symlink';

        # if only pgdata symlink is present, it is authoritative
        PgCommon::disable_conf_value $v, 'main', 'postgresql.conf', 'data_directory', 'disabled for test';
        is_program_out 0, "pg_ctlcluster $v main start", 0, '',
            'cluster restarts with pgdata symlink';
    } else {
        pass 'Skipping pgdata symlink compatibility test for versions before 8.0';
        pass '...';
        pass '...';
        pass '...';
        pass '...';
    }

    # Drop database and user again.
    sleep 1;
    is ((exec_as 'nobody', 'dropdb nobodydb', $outref, 0), 0, 'dropdb nobodydb', );
    is ((exec_as 'postgres', 'dropuser nobody', $outref, 0), 0, 'dropuser nobody');

    # stop server, clean up, check for leftovers
    ok ((system "pg_dropcluster $v main --stop") == 0, 
	'pg_dropcluster removes cluster');

    check_clean;
}

foreach (@MAJORS) { 
    check_major $_;
}

# vim: filetype=perl
