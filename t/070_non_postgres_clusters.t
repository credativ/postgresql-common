# Test successful operation of clusters which are not owned by
# postgres. Only check the oldest and newest version.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 52; # 54 if conf.d is present

$ENV{_SYSTEMCTL_SKIP_REDIRECT} = 1; # FIXME: testsuite is hanging otherwise

my $owner = 'nobody';
my $v = $MAJORS[0];

# create cluster
is ((system "pg_createcluster -u $owner $v main >/dev/null"), 0,
    "pg_createcluster $v main for owner $owner");

# check if start is refused when config and data owner do not match
my $pgconf = "/etc/postgresql/$v/main/postgresql.conf";
my ($origuid, $origgid) = (stat $pgconf)[4,5];
chown 1, 1, $pgconf;
like_program_out 0, "pg_ctlcluster $v main start", 1, qr/do not match/, "start refused when config and data owners mismatch";
chown $origuid, $origgid, $pgconf;
is ((system "pg_ctlcluster $v main start"), 0, "pg_ctlcluster succeeds with owner $owner");

# Check cluster
like_program_out $owner, 'pg_lsclusters -h', 0, 
    qr/^$v\s+main\s+5432\s+online\s+$owner/, 
    'pg_lsclusters shows running cluster';

like ((ps 'postgres'), qr/^$owner.*bin\/postgres .*\/var\/lib\/postgresql\/$v\/main/m,
    "postgres is running as user $owner");

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
is ((ps 'postgres'), '', "No postgres processes left");

check_clean;

# vim: filetype=perl
