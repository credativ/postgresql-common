# Check operation with multiple clusters

use strict; 

use lib 't';
use TestLib;
use Socket;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 127;

# Replace all md5 and password authentication methods with 'trust' in given
# pg_hba.conf file.
sub hba_password_to_ident {
    open F, $_[0] or die "open $_[0]: $!";
    my $hba;
    read F, $hba, 10000;
    $hba =~ s/md5/trust/g;
    $hba =~ s/password/trust/g;
    close F;
    open F, ">$_[0]" or die "open $_[0]: $!";
    print F $hba;
    close F;
    chmod 0644, $_[0] or die "chmod $_[0]: $!";
}

# create fake socket at 5433 to verify that this port is skipped
socket (SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp')) or die "socket: $!";
bind (SOCK, sockaddr_in(5433, INADDR_ANY)) || die "bind: $! ";

# create clusters
is ((system "pg_createcluster $MAJORS[0] old >/dev/null"), 0, "pg_createcluster $MAJORS[0] old");
is ((system "pg_createcluster $MAJORS[-1] new1 >/dev/null"), 0, "pg_createcluster $MAJORS[-1] new1");
is ((system "pg_createcluster $MAJORS[-1] new2 -p 5440 >/dev/null"), 0, "pg_createcluster $MAJORS[-1] new2");

my $old = "$MAJORS[0]/old";
my $new1 = "$MAJORS[-1]/new1";
my $new2 = "$MAJORS[-1]/new2";

# disable password auth for network cluster selection tests
hba_password_to_ident "/etc/postgresql/$old/pg_hba.conf";
hba_password_to_ident "/etc/postgresql/$new1/pg_hba.conf";
hba_password_to_ident "/etc/postgresql/$new2/pg_hba.conf";

is ((system "pg_ctlcluster $MAJORS[0] old start >/dev/null"), 0, "starting cluster $old");
is ((system "pg_ctlcluster $MAJORS[-1] new1 start >/dev/null"), 0, "starting cluster $new1");
is ((system "pg_ctlcluster $MAJORS[-1] new2 start >/dev/null"), 0, "starting cluster $new2");

like_program_out 'postgres', 'pg_lsclusters -h | sort -k3', 0, qr/.*5432.*5434.*5440.*/s,
    'clusters have the correct ports, skipping used 5433';

# move user_clusters aside for the test; this will ensure that client programs
# work correctly without any file at all
if (-f '/etc/postgresql-common/user_clusters') {
    ok ((rename '/etc/postgresql-common/user_clusters',
    '/etc/postgresql-common/user_clusters.psqltestsuite'),
    'Temporarily moving away /etc/postgresql-common/user_clusters');
} else {
    pass '/etc/postgresql-common/user_clusters does not exist';
}

# check basic cluster selection
like_program_out 0, 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[0]/, 
    'pg_wrapper selects port 5432 as default cluster';
like_program_out 0, "psql --cluster $new1 --version", 0, 
    qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'pg_wrapper --cluster works';
like_program_out 0, "psql --cluster $MAJORS[-1]/foo --version", 1, 
    qr/Specified cluster does not exist/,
    'pg_wrapper --cluster errors out for invalid cluster';

# create a database in new1 and check that it doesn't appear in new2
is_program_out 'postgres', "createdb --cluster $new1 test", 0, '';
like_program_out 'postgres', "psql -Atl --cluster $new1", 0, 
    qr/test\|postgres\|/,
    'test db appears in cluster new1';
unlike_program_out 'postgres', "psql -Atl --cluster $new2", 0, 
    qr/test\|postgres\|/,
    'test db does not appear in cluster new2';
unlike_program_out 'postgres', "psql -Atl", 0, qr/test\|postgres\|/,
    'test db does not appear in default cluster';

# check network cluster selection
is_program_out 'postgres', "psql --cluster $MAJORS[0]/127.0.0.1: -Atc 'show port' template1", 0, "5432\n", 
    "psql --cluster $MAJORS[0]/127.0.0.1: defaults to port 5432";
like_program_out 'postgres', "psql --cluster $MAJORS[-1]/127.0.0.1:5432 --version", 0, 
    qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    "psql --cluster $MAJORS[-1]/127.0.0.1:5432 uses latest client version";
like_program_out 'postgres', "psql -Atl --cluster $MAJORS[-1]/localhost:5434", 0, 
    qr/test\|postgres\|/, "test db appears in cluster $MAJORS[-1]/localhost:5434";
unlike_program_out 'postgres', "psql -Atl --cluster $MAJORS[-1]/localhost:5440", 0, 
    qr/test\|postgres\|/, "test db does not appear in cluster $MAJORS[-1]/localhost:5440";

# check some erroneous cluster specifications
like_program_out 'postgres', "LC_MESSAGES=C psql -Atl --cluster $MAJORS[-1]/localhost:5435", 2, 
    qr/could not connect/, "psql --cluster $MAJORS[-1]/localhost:5435 fails due to nonexisting port";
like_program_out 'postgres', "LC_MESSAGES=C psql -Atl --cluster $MAJORS[-1]/localhost:a", 1, 
    qr/Specified cluster does not exist/, "psql --cluster $MAJORS[-1]/localhost:a fails due to invalid syntax";
like_program_out 'postgres', "LC_MESSAGES=C psql -Atl --cluster $MAJORS[-1]/doesnotexi.st", 1, 
    qr/Specified cluster does not exist/, "psql --cluster $MAJORS[-1]/doesnotexi.st fails due to invalid syntax";
like_program_out 'postgres', "psql -Atl --cluster 6.4/localhost:", 1, 
    qr/Invalid version/, "psql --cluster 6.4/localhost: fails due to invalid version";

# check that environment variables work
$ENV{'PGCLUSTER'} = $new1;
like_program_out 'postgres', "psql -Atl", 0, qr/test\|postgres\|/, 
    'PGCLUSTER selection (1)';
$ENV{'PGCLUSTER'} = $new2;
unlike_program_out 'postgres', "psql -Atl", 0, qr/test\|postgres\|/, 
    'PGCLUSTER selection (2)';
$ENV{'PGCLUSTER'} = 'foo';
like_program_out 'postgres', "psql -l", 1, 
    qr/Invalid version specified with \$PGCLUSTER/, 
    'invalid PGCLUSTER value';
$ENV{'PGCLUSTER'} = "$MAJORS[-1]/127.0.0.1:";
like_program_out 0, 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'PGCLUSTER network cluster selection (1)';
$ENV{'PGCLUSTER'} = "$MAJORS[-1]/localhost:5434";
like_program_out 'postgres', 'psql -Atl', 0, 
    qr/test\|postgres\|/, 'PGCLUSTER network cluster selection (2)';
$ENV{'PGCLUSTER'} = "$MAJORS[-1]/localhost:5440";
unlike_program_out 'postgres', 'psql -Atl', 0, 
    qr/test\|postgres\|/, 'PGCLUSTER network cluster selection (3)';
$ENV{'PGCLUSTER'} = "$MAJORS[-1]/localhost:5435";
like_program_out 'postgres', 'LC_MESSAGES=C psql -Atl', 2, 
    qr/could not connect/, "psql --cluster $MAJORS[-1]/localhost:5435 fails due to nonexisting port";
delete $ENV{'PGCLUSTER'};

# check that PGPORT works
$ENV{'PGPORT'} = '5434';
is_program_out 'postgres', 'psql -Atc "show port" template1', 0, "5434\n", 
    'PGPORT selection (1)';
$ENV{'PGPORT'} = '5432';
is_program_out 'postgres', 'psql -Atc "show port" template1', 0, "5432\n", 
    'PGPORT selection (2)';
$ENV{'PGCLUSTER'} = $new2;
delete $ENV{'PGPORT'};
$ENV{'PGPORT'} = '5432';
like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'PGPORT+PGCLUSTER, PGCLUSTER selects version';
is_program_out 'postgres', 'psql -Atc "show port" template1', 0, "5432\n", 
    'PGPORT+PGCLUSTER, PGPORT selects port';
delete $ENV{'PGPORT'};
delete $ENV{'PGCLUSTER'};

# check that PGDATABASE works
$ENV{'PGDATABASE'} = 'test';
is_program_out 'postgres', "psql --cluster $new1 -Atc 'select current_database()'", 0, "test\n", 
    'PGDATABASE environment variable works';
delete $ENV{'PGDATABASE'};

# check cluster selection with an empty user_clusters
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
like_program_out 0, 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[0]/, 
    'pg_wrapper selects port 5432 as default cluster with empty user_clusters';
like_program_out 0, "psql --cluster $new1 --version", 0, 
    qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'pg_wrapper --cluster works with empty user_clusters';

# check default cluster selection with user_clusters
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
print F "* * $MAJORS[-1] new1 *\n";
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    "pg_wrapper selects correct cluster with user_clusters '* * $MAJORS[-1] new1 *'";

# check default database selection with user_clusters
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
print F "* * $MAJORS[-1] new1 test\n";
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
is_program_out 'postgres', 'psql -Atc "select current_database()"', 0, "test\n",
    "pg_wrapper selects correct database with user_clusters '* * $MAJORS[-1] new1 test'";
$ENV{'PGDATABASE'} = 'template1';
is_program_out 'postgres', "psql -Atc 'select current_database()'", 0, "template1\n", 
    'PGDATABASE environment variable is not overridden by user_clusters';
delete $ENV{'PGDATABASE'};

# check by-user cluster selection with user_clusters
# (also check invalid cluster reporting)
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
print F "postgres * $MAJORS[-1] new1 *\nnobody * $MAJORS[0] old *\n* * 5.5 * *";
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'pg_wrapper selects correct cluster with per-user user_clusters';
like_program_out 'nobody', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[0]/, 
    'pg_wrapper selects correct cluster with per-user user_clusters';
like_program_out 0, 'psql --version', 1, qr/user_clusters.*line 3.*version.*not exist/i, 
    'pg_wrapper error for invalid per-user user_clusters line';

# check by-user network cluster selection with user_clusters
# (also check invalid cluster reporting)
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
print F "postgres * $MAJORS[0] localhost: *\nnobody * $MAJORS[-1] new1 *\n* * $MAJORS[-1] localhost:a *";
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
like_program_out 'postgres', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[0]/, 
    'pg_wrapper selects correct version with per-user user_clusters';
like_program_out 'nobody', 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'pg_wrapper selects correct version with per-user user_clusters';
like_program_out 0, 'psql --version', 1, qr/user_clusters.*line 3.*cluster.*not exist/i, 
    'pg_wrapper error for invalid per-user user_clusters line';
# check PGHOST environment variable precedence
$ENV{'PGHOST'} = '127.0.0.2';
like_program_out 'postgres', 'psql -Atl', 2, qr/127.0.0.2/, '$PGHOST overrides user_clusters';
is_program_out 'postgres', "psql --cluster $MAJORS[-1]/localhost:5434 -Atc 'select current_database()' test", 
    0, "test\n", '--cluster overrides $PGHOST';
delete $ENV{'PGHOST'};

# check invalid user_clusters
open F, '>/etc/postgresql-common/user_clusters' or die "Could not create user_clusters: $!";
print F 'foo';
close F;
chmod 0644, '/etc/postgresql-common/user_clusters';
like_program_out 'postgres', 'psql --version', 0, qr/ignoring invalid line 1/, 
    'pg_wrapper ignores invalid lines in user_clusters';

# remove test user_clusters
unlink '/etc/postgresql-common/user_clusters' or die
    "unlink user_clusters: $!";

# check that pg_service.conf works
open F, '>/etc/postgresql-common/pg_service.conf' or die "Could not create pg_service.conf: $!";
print F "[old_t1]
user=postgres
dbname=template1
port=5432

[new1_test]
user=postgres
dbname=test
port=5434

# these do not exist
[new2_test]
user=postgres
dbname=test
port=5440
";
close F;
chmod 0644, '/etc/postgresql-common/pg_service.conf';
$ENV{'PGSERVICE'} = 'old_t1';
# TODO: sysconfdir is only fixed in 8.3 for now
is_program_out 'postgres', "/usr/lib/postgresql/$MAJORS[-1]/bin/psql -Atc 'select current_database()'", 0,
    "template1\n", 'pg_service conf selection 1';
$ENV{'PGSERVICE'} = 'new1_test';
is_program_out 'postgres', "/usr/lib/postgresql/$MAJORS[-1]/bin/psql -Atc 'select current_database()'", 0,
    "test\n", 'pg_service conf selection 2';
$ENV{'PGSERVICE'} = 'new2_test';
like_program_out 'postgres', "/usr/lib/postgresql/$MAJORS[-1]/bin/psql -Atc 'select current_database()'", 2,
    qr/FATAL.*test/, 'pg_service conf selection 3';
delete $ENV{'PGSERVICE'};
unlink '/etc/postgresql-common/pg_service.conf';

# check proper error message if no cluster could be determined as default for
# pg_wrapper
is ((system "pg_ctlcluster $MAJORS[0] old stop >/dev/null"), 0, "stopping cluster $old");
PgCommon::set_conf_value $MAJORS[0], 'old', 'postgresql.conf', 'port', '5435';
is ((system "pg_ctlcluster $MAJORS[0] old start >/dev/null"), 0, "restarting cluster $old");
like_program_out 'postgres', 'pg_lsclusters -h | sort -k3', 0, qr/.*5434.*5435.*5440.*/s,
    'port of first cluster was successfully changed';
like_program_out 'postgres', "psql -l", 1, 
    qr/no.*default.*man pg_wrapper/i,
    'proper pg_wrapper error message if no cluster is suitable as target';
like_program_out 'postgres', "psql -Atl --cluster $new1", 0, 
    qr/test\|postgres\|/,
    '--cluster selects appropriate cluster';
like_program_out 'postgres', "psql -Atl -p 5434", 0, 
    qr/test\|postgres\|/,
    '-p selects appropriate cluster';
like_program_out 'postgres', "psql -Atlp 5434", 0, 
    qr/test\|postgres\|/,
    '-Atlp selects appropriate cluster';
like_program_out 'postgres', "psql -Atl --port 5434", 0, 
    qr/test\|postgres\|/,
    '--port selects appropriate cluster';
like_program_out 'postgres', "env PGPORT=5434 psql -Atl", 0, 
    qr/test\|postgres\|/,
    '$PGPORT selects appropriate cluster';

# but specifying -p explicitly should work

# restore original user_clusters
if (-f '/etc/postgresql-common/user_clusters.psqltestsuite') {
    ok ((rename '/etc/postgresql-common/user_clusters.psqltestsuite',
    '/etc/postgresql-common/user_clusters'),
    'Restoring original /etc/postgresql-common/user_clusters');
} else {
    pass '/etc/postgresql-common/user_clusters did not exist, not restoring';
}

# clean up
is ((system "pg_dropcluster $MAJORS[-1] new1 --stop"), 0, "dropping $new1");
is ((system "pg_dropcluster $MAJORS[-1] new2 --stop"), 0, "dropping $new2");
is ((system "pg_dropcluster $MAJORS[0] old --stop"), 0, "dropping $old");

check_clean;

# vim: filetype=perl
