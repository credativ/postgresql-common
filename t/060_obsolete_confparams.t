# Test upgrading from the oldest version to all majors with all possible
# configuration parameters set. This checks that they are correctly
# transitioned.

use strict;

use lib 't';
use TestLib;

use Test::More tests => (@MAJORS == 1) ? 1 : (15 + @MAJORS * 12);

if (@MAJORS == 1) {
    pass 'only one major version installed, skipping upgrade tests';
    exit 0;
}

$ENV{_SYSTEMCTL_SKIP_REDIRECT} = 1; # FIXME: testsuite is hanging otherwise

# t/$v.conf generated using
# sed -e 's/^#//' -e 's/[ \t]*#.*//g' /etc/postgresql/12/main/postgresql.conf | grep '^[a-z]'
# remove/comment data_directory, hba_file, ident_file, external_pid_file, include_dir, include
# include_if_exists should be 'exists.conf'
# lc_* should be 'C'
# stats_temp_directory should point to /var/run/postgresql/*.pg_stat_tmp

# Test one particular upgrade (old version, new version)
sub do_upgrade {
    my $cur = $_[0];
    my $new = $_[1];
    note "Testing upgrade $cur -> $new";

    open C, "t/$cur.conf" or die "could not open t/$cur.conf: $!";
    my $fullconf;
    { local $/; $fullconf = <C>; }
    close C;

    # Write configuration file and start
    my $datadir = PgCommon::cluster_data_directory $cur, 'main';
    open F, ">/etc/postgresql/$cur/main/postgresql.conf" or 
        die "could not open /etc/postgresql/$cur/main/postgresql.conf";
    print F $fullconf;
    close F;
    # restore data directory, we just scribbled over it
    PgCommon::set_conf_value $cur, 'main', 'postgresql.conf', 'data_directory', $datadir;
    
    is_program_out 0, "pg_ctlcluster $cur main start", 0, "";
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$cur.*online/, 
        "Old $cur cluster is online";

    # Upgrade cluster
    like_program_out 0, "env LC_MESSAGES=C pg_upgradecluster -v $new $cur main", 0, qr/^Success/im;
    like_program_out 'postgres', 'pg_lsclusters -h', 0, qr/$new.*online/,
        "New $new cluster is online";

    is_program_out 0, "pg_dropcluster $cur main", 0, "";
    is_program_out 0, "pg_ctlcluster $new main stop", 0, "";
}

# create cluster for oldest version
is_program_out 0, "pg_createcluster $MAJORS[0] main >/dev/null", 0, "";

# Loop over all but the latest major version, testing N->N+1 upgrades
my @testversions = sort { $a <=> $b } @MAJORS;
while ($#testversions) {
    my $cur = shift @testversions;
    my $new = $testversions[0];
    do_upgrade $cur, $new;
}

# remove latest cluster and directory
is_program_out 0, "pg_dropcluster $testversions[0] main", 0, "";

# now test a direct upgrade from oldest to newest, to also catch parameters
# which changed several times, like syslog -> redirect_stderr ->
# logging_collector
if ($#MAJORS > 1) {
    is_program_out 0, "pg_createcluster $MAJORS[0] main >/dev/null", 0, "";
    do_upgrade $MAJORS[0], $MAJORS[-1];
    is ((system "pg_dropcluster $testversions[0] main"), 0, 'Dropping remaining cluster');
} else {
    pass 'only two available versions, skipping tests...';
    for (my $i = 0; $i < 14; ++$i) {
        pass '...';
    }
}

check_clean;

# vim: filetype=perl
