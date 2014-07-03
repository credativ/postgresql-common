# Test successful operation of clusters which are not owned by
# postgres. Only check the oldest and newest version.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 49;

my $owner = 'nobody';
my $v = $MAJORS[0];

# create cluster
is ((system "pg_createcluster -u $owner $v main --start >/dev/null"), 0,
    "pg_createcluster $v main for owner $owner");

# Check cluster
like_program_out $owner, 'pg_lsclusters -h', 0, 
    qr/^$v\s+main\s+5432\s+online\s+$owner/, 
    'pg_lsclusters shows running cluster';

my $master_process = ($v >= '8.2') ? 'postgres' : 'postmaster';
like ((ps $master_process), qr/^$owner.*bin\/$master_process .*\/var\/lib\/postgresql\/$v\/main/m,
    "$master_process is running as user $owner");

is_program_out $owner, 'ls /tmp/.s.PGSQL.*', 0, "/tmp/.s.PGSQL.5432\n/tmp/.s.PGSQL.5432.lock\n", 'socket is in /tmp';

ok_dir '/var/run/postgresql', [], '/var/run/postgresql is empty';

# verify owner of configuration files
my @st;
my $confdir = "/etc/postgresql/$v/main";
my ($owneruid, $ownergid) = (getpwnam $owner)[2,3];
@st = stat $confdir;
is $st[4], $owneruid, 'conf dir is owned by user';
is $st[5], $ownergid, 'conf dir is owned by user\'s primary group';
opendir D, $confdir or die "opendir: $!";
for my $f (readdir D) {
    next if $f eq '.' or $f eq '..';
    @st = stat "$confdir/$f" or die "stat: $!";
    is $st[4], $owneruid, "$f is owned by user";
    is $st[5], $ownergid, "$f is owned by user\'s primary group";
}

# verify log file properties
@st = stat "/var/log/postgresql/postgresql-$v-main.log";
is $st[2], 0100640, 'log file has 0640 permissions';
is $st[4], $owneruid, 'log file is owned by user';
# the log file gid setting works on RedHat, but nobody has gid 99 there (and
# there's not good alternative for testing)
my $loggid = $PgCommon::rpm ? (getgrnam 'adm')[2] : $ownergid;
is $st[5], $loggid, 'log file is owned by user\'s primary group';

if ($#MAJORS > 0) {
    my $newv = $MAJORS[-1];

    my $outref;
    is ((exec_as 0, "(pg_upgradecluster -v $newv $v main | sed -e 's/^/STDOUT: /')", $outref, 0), 0, 
	'pg_upgradecluster succeeds');
    like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
    like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';
    my @err = grep (!/^STDOUT: /, split (/\n/, $$outref));
    if (@err) {
	fail 'no error messages during upgrade';
	print (join ("\n", @err));
    } else {
	pass "no error messages during upgrade";
    }

    # verify file permissions
    @st = stat "/etc/postgresql/$newv/main";
    is $st[4], $owneruid, 'upgraded conf dir is owned by user';
    is $st[5], $ownergid, 'upgraded conf dir is owned by user\'s primary group';
    @st = stat "/etc/postgresql/$newv/main/postgresql.conf";
    is $st[4], $owneruid, 'upgraded postgresql.conf dir is owned by user';
    is $st[5], $ownergid, 'upgraded postgresql.conf dir is owned by user\'s primary group';
    @st = stat "/var/log/postgresql/postgresql-$v-main.log";
    is $st[4], $owneruid, 'upgraded log file is owned by user';
    is $st[5], $loggid, 'upgraded log file is owned by user\'s primary group';

    is ((system "pg_dropcluster $newv main --stop"), 0, 'pg_dropcluster');
} else {
    pass 'only one major version installed, skipping upgrade test';
    for (my $i = 0; $i < 10; ++$i) {
	pass '...';
    }
}

# Check proper cleanup
is ((system "pg_dropcluster $v main --stop"), 0, 'pg_dropcluster');
is_program_out $owner, 'pg_lsclusters -h', 0, '', 'No clusters left';
is ((ps $master_process), '', "No $master_process processes left");

check_clean;

# vim: filetype=perl
