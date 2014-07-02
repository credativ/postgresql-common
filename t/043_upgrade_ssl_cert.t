# Test cluster upgrade with a custom ssl certificate

use strict; 

use File::Temp qw/tempdir/;

use lib 't';
use TestLib;

use Test::More tests => ($#MAJORS == 0 or $PgCommon::rpm) ? 1 : 24;

if ($#MAJORS == 0) {
    pass 'only one major version installed, skipping upgrade tests';
    exit 0;
}
if ($PgCommon::rpm) {
    pass 'SSL certificates not handled on RedHat';
    exit 0;
}

use lib '/usr/share/postgresql-common';
use PgCommon;

ok ((system "pg_createcluster $MAJORS[0] upgr >/dev/null") == 0);

my $tdir = tempdir (CLEANUP => 1);
my ($p_uid, $p_gid) = (getpwnam 'postgres')[2,3];
chown $p_uid, $p_gid, $tdir;

my $tempcrt = "$tdir/ssl-cert-snakeoil.pem";
my $oldcrt = "/var/lib/postgresql/$MAJORS[0]/upgr/server.crt";
my $newcrt = "/var/lib/postgresql/$MAJORS[-1]/upgr/server.crt";

# First upgrade
note "upgrade test: server.crt is a symlink";
(system "cp -p /etc/ssl/certs/ssl-cert-snakeoil.pem $tempcrt") == 0 or die "cp: $!";
unlink $oldcrt; # remove file installed by pg_createcluster
symlink $tempcrt, $oldcrt or die "symlink: $!";

# Upgrade to latest version
my $outref;
is ((exec_as 0, "pg_upgradecluster -v $MAJORS[-1] $MAJORS[0] upgr", $outref, 0), 0, 'pg_upgradecluster succeeds');
like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

if ($MAJORS[-1] >= 9.2) {
    is ((-e $newcrt), undef, "new data directory does not contain server.crt");
    is ((PgCommon::get_conf_value $MAJORS[-1], 'upgr', 'postgresql.conf', 'ssl_cert_file'),
	$tempcrt, "symlink server.crt target is put into ssl_cert_file");
} else {
    is ((-l $newcrt), 1, "new data directory contains server.crt");
    is ((readlink $newcrt), $tempcrt, "symlink server.crt points to correct location");
}

# Clean away new cluster
is ((system "pg_dropcluster $MAJORS[-1] upgr --stop"), 0, 'Dropping upgraded cluster');
unlink $oldcrt or die "unlink: $!";

# Second upgrade
note "upgrade test: server.crt is a plain file";
(system "cp -p $tempcrt $oldcrt") == 0 or die "cp: $!";

# Upgrade to latest version
my $outref;
is ((exec_as 0, "pg_upgradecluster -v $MAJORS[-1] $MAJORS[0] upgr", $outref, 0), 0, 'pg_upgradecluster succeeds');
like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

is ((-f $newcrt), 1, "new data directory contains server.crt file");
if ($MAJORS[-1] >= 9.2) {
    is ((PgCommon::get_conf_value $MAJORS[-1], 'upgr', 'postgresql.conf', 'ssl_cert_file'),
	$newcrt, "server.crt is put into ssl_cert_file");
} else {
    pass "...";
}

# Stop servers, clean up
is ((system "pg_dropcluster $MAJORS[0] upgr"), 0, 'Dropping original cluster');
is ((system "pg_dropcluster $MAJORS[-1] upgr --stop"), 0, 'Dropping upgraded cluster');

check_clean;

# vim: filetype=perl
