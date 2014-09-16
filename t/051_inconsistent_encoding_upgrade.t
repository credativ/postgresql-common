# Starting from 8.3, postgresql enforces DB encoding/server locale matching;
# Check that upgrades from broken combinations get fixed on upgrade, and that
# the upgrade succeeds.

use strict; 

use lib 't';
use TestLib;
use PgCommon;
use Test::More tests => ($#MAJORS == 0 || $MAJORS[0] >= '8.3') ? 1 : 19 * 3 + 10;

if ($#MAJORS == 0) {
        pass 'only one major version installed, skipping upgrade tests';
        exit 0;
}

if ($MAJORS[0] >= '8.3') {
        pass 'test only relevant for oldest version < 8.3, skipping';
        exit 0;
}

# Arguments: <locale> [<old version>] [<new version>]
sub test_upgrade {
    my $outref;
    my $locale = $_[0];
    my $oldv = $_[1] || $MAJORS[0];
    my $newv = $_[2] || $MAJORS[-1];

    is ((exec_as 0, "pg_createcluster --start --locale=$locale $oldv main", $outref), 0,
        "creating $locale $oldv cluster");

    is ((exec_as 'postgres', 'psql -c "create user latinuser; 
        create user utf8user;
        create database utf8test owner = utf8user encoding = \'UTF8\';
        create database latintest owner = latinuser encoding = \'iso-8859-5\';" template1', $outref), 0,
        "creating DBs with different encodings");
   
    # encodings should be automatic with a proper locale, but not in C
    my $eu = ($locale eq 'C') ? "set client_encoding='UTF8'; " : '';
    my $el = ($locale eq 'C') ? "set client_encoding='iso-8859-5'; " : '';

    is ((exec_as 'postgres', "printf 'A\\320\\264B' | psql -c \"$eu create table t(x varchar); copy t from stdin\" utf8test", $outref), 
        0, 'write UTF8 database content');
    is ((exec_as 'postgres', "printf 'A\\324B' | psql -c \"$el create table t(x varchar); copy t from stdin\" latintest", $outref), 
        0, 'write LATIN database content');

    is_program_out 'postgres', "echo \"$eu select * from t\" | psql -Atq utf8test", 0, "AдB\n", 
        'old utf8test DB has correctly encoded string';
    is_program_out 'postgres', "echo \"$el select * from t\" | psql -Atq latintest",
        0, "A\324B\n", 'old latintest DB has correctly encoded string';

    like_program_out 0, "pg_upgradecluster -v $newv $oldv main", 0, qr/^Success/im;

    is ((system "pg_dropcluster --stop $oldv main"), 0, 'dropping old cluster');

    # in C we cannot change encoding, thus it will be what we put in; in proper
    # locales it defaults to the server encoding, so we have to specify it
    # explicitly
    my $el = ($locale eq 'C') ? '' : "set client_encoding='iso-8859-5'; ";
    my $eu = ($locale eq 'C') ? '' : "set client_encoding='UTF-8'; ";
    is_program_out 'postgres', "echo \"$eu select * from t\" | psql -Atq utf8test", 0, "AдB\n", 
        'upgraded utf8test DB has correctly encoded string';
    is_program_out 'postgres', "echo \"$el select * from t\" | psql -Atq latintest",
        0, "A\324B\n", 'upgraded latintest DB has correctly encoded string';

    is ((exec_as 'postgres', 'psql -Atl', $outref), 0, 'psql -Atl on upgraded cluster');
    if ($locale eq 'C') {
        # verify ownership; encodings should be retained in C
        ok ((index $$outref, 'latintest|latinuser|ISO_8859_5') >= 0, 
            'latintest is owned by latinuser and is ISO8859-5 encoded');
        ok ($$outref =~ qr/^utf8test\|utf8user\|(UTF8|UNICODE)$/m, 
            'utf8test is owned by utf8user and is UTF8 encoded');
    } else {
        # verify ownership; encodings have been corrected on upgrade
        ok ((index $$outref, 'latintest|latinuser') >= 0, 'latinuser is owned by latintest');
        ok ((index $$outref, 'utf8test|utf8user') >= 0, 'utf8user is owned by utf8test');
    }

    is ((system "pg_dropcluster --stop $newv main"), 0, 'dropping upgraded cluster');
}

test_upgrade 'C';
test_upgrade 'ru_RU.UTF-8';
test_upgrade 'ru_RU', $MAJORS[0], $MAJORS[1];

check_clean;

# vim: filetype=perl
