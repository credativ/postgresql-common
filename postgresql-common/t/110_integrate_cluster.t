# Check integration of an already existing cluster

use strict; 

use lib 't';
use TestLib;
use File::Temp qw/tempdir/;

my $version = $MAJORS[-1];

use Test::More tests => 34;

use lib '/usr/share/postgresql-common';
use PgCommon;

delete $ENV{'LANG'};
delete $ENV{'LANGUAGE'};
$ENV{'LC_ALL'} = 'C';

my $wdir = tempdir (CLEANUP => 1);
chmod 0755, $wdir or die "Could not chmod $wdir: $!";

# create clusters for different owners and check their integration
for my $o ('postgres', 'nobody') {
    my $cdir = "$wdir/c";
    mkdir $cdir;
    my $oid = getpwnam $o;
    chown $oid, 0, $cdir or die "Could not chown $cdir to $oid: $!";
    like_program_out $o, "/usr/lib/postgresql/$version/bin/initdb $cdir/$o", 
	0, qr/Success/, "creating raw initdb cluster for user $o";
    like_program_out 0, "pg_createcluster $version $o -d $cdir/$o", 0, 
	qr/Configuring already existing cluster/i, "integrating $o cluster";
    like_program_out 0, "pg_lsclusters", 0,
	qr/$version\s+$o\s+5432\s+down\s+$o\s/, 'correct pg_lsclusters output';
    is_program_out $o, "pg_ctlcluster $version $o start", 0, '', "starting cluster $o";
    like_program_out 0, "pg_lsclusters", 0,
	qr/$version\s+$o\s+5432\s+online\s+$o\s/, 'correct pg_lsclusters output';
    is ((system "pg_dropcluster $version $o --stop"), 0, "dropping cluster $o");
    ok_dir $cdir, [], 'No files in temporary cluster dir left behind';
    rmdir $cdir;
}

check_clean;

# vim: filetype=perl
