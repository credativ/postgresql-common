# Check that cluster administration works as non-root if the invoker has
# sufficient permissions on directories.

use strict; 

use lib 't';
use TestLib;

my $ownver = $MAJORS[-1];
my $grpver = $MAJORS[0];

use Test::More tests => 36;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $testuser = 'postgres';
my ($uid, $gid) = (getpwnam $testuser)[2,3];

# fails by default due to access restrictions
like_program_out $testuser, "pg_createcluster $ownver fail --start", 1,
    qr/root privileges/, "pg_createcluster fails as user $testuser by default";
# and does not leave any garbage behind
check_clean;

# prepare directories to that we can access it as owner/group
die "could not mkdir: $!" if system "mkdir -p /etc/postgresql/$ownver /etc/postgresql/$grpver /var/log/postgresql /var/lib/postgresql/$ownver /var/lib/postgresql/$grpver";
chown $uid, 0, "/etc/postgresql/$ownver", "/var/lib/postgresql/$ownver";
chown 0, $gid, "/etc/postgresql/$grpver", "/var/log/postgresql", "/var/lib/postgresql/$grpver";
chmod 0775, "/etc/postgresql/$grpver", "/var/log/postgresql", "/var/lib/postgresql/$grpver";

# pg_createcluster and pg_ctlcluster
is ((exec_as $testuser, "pg_createcluster $ownver own --start"), 0,
    "pg_createcluster succeeds as user $testuser with appropriate owner permissions");
is ((exec_as $testuser, "pg_createcluster $grpver grp --start"), 0,
    "pg_createcluster succeeds as user $testuser with appropriate group permissions");

like_program_out $testuser, 'pg_lsclusters -h', 0,
    qr/^$grpver\s+grp.*online.*\n^$ownver\s+own.*online/m;
like_program_out 'postgres', 'psql -Atl', 0, qr/template1.*UTF8/;

# pg_dropcluster
is ((exec_as $testuser, "pg_dropcluster $ownver own --stop"), 0,
    "pg_dropcluster succeeds as user $testuser with appropriate directory owner permissions");

# pg_upgradecluster
if ($grpver ne $ownver) {
    my $outref;
    is ((exec_as $testuser, "pg_upgradecluster $grpver grp", $outref, 0), 0, 
        "pg_upgradecluster succeeds as user $testuser");
    like $$outref, qr/Starting target cluster/, 'pg_upgradecluster reported cluster startup';
    like $$outref, qr/Success. Please check/, 'pg_upgradecluster reported successful operation';

    like_program_out $testuser, 'pg_lsclusters -h', 0,
        qr/^$grpver\s+grp.*down.*\n^$ownver\s+grp.*online/m;

    # clean up
    is ((exec_as $testuser, "pg_dropcluster $grpver grp"), 0);
    is ((exec_as $testuser, "pg_dropcluster $ownver grp --stop"), 0);
} else {
    pass 'Only one major version installed, skipping pg_upgradecluster tests';
    for (my $i = 0; $i < 5; ++$i) { pass '...'; }

    is ((exec_as $testuser, "pg_dropcluster $grpver grp --stop"), 0);
}

# we cannot expect full cleanliness of /{etc,var/lib}/postgresql since that
# requires root permissions; thus help a bit
rmdir "/etc/postgresql/$ownver";
rmdir "/etc/postgresql/$grpver";
rmdir "/var/lib/postgresql/$ownver";
rmdir "/var/lib/postgresql/$grpver";
check_clean;

# vim: filetype=perl
