# Starting from 8.3, postgresql enforces DB encoding/server locale matching;
# Check that upgrades from broken combinations get fixed on upgrade, and that
# the upgrade succeeds.

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 19 * 2 + 10;

use lib '/usr/share/postgresql-common';
use PgCommon;


# Arguments: <locale> [<old version>] [<new version>]
sub test_upgrade {
    my $outref;
    my $locale = $_[0];
    my $oldv = $_[1] || $MAJORS[0];
    my $newv = $_[2] || $MAJORS[-1];

    is ((exec_as 0, "pg_createcluster --start --locale=$locale $oldv main", $outref), 0,
        "creating $locale cluster");

    is ((exec_as 'postgres', 'psql -c "create user latin1user; 
        create user utf8user;
        create database utf8test owner = utf8user encoding = \'UTF8\';
        create database latin1test owner = latin1user encoding = \'latin1\';" template1', $outref), 0,
        "creating DBs with different encodings");
   
    # encodings should be automatic with a proper locale, but not in C
    my $eu = ($locale eq 'C') ? "set client_encoding='UTF8'; " : '';
    my $el = ($locale eq 'C') ? "set client_encoding='latin1'; " : '';

    is ((exec_as 'postgres', "printf 'A\\xC3\\xB6B' | psql -c '$eu create table t(x varchar); copy t from stdin' utf8test", $outref), 
        0, 'write UTF8 database content');
    is ((exec_as 'postgres', "printf 'A\\xF6B' | psql -c '$el create table t(x varchar); copy t from stdin' latin1test", $outref), 
        0, 'write LATIN1 database content');

    is_program_out 'postgres', "echo '$eu select * from t' | psql -Atq utf8test", 0, "AöB\n", 
        'old utf8test DB has correctly encoded string';
    is_program_out 'postgres', "echo '$el select * from t' | psql -Atq latin1test",
        0, "A\xF6B\n", 'old latin1test DB has correctly encoded string';

    like_program_out 0, "pg_upgradecluster $oldv main", 0, qr/^Success/im;

    is ((system "pg_dropcluster --stop $oldv main"), 0, 'dropping old cluster');

    is_program_out 'postgres', "echo '$eu select * from t' | psql -Atq utf8test", 0, "AöB\n", 
        'upgraded utf8test DB has correctly encoded string';
    # in C we cannot change encoding, thus it will be what we put in; in proper
    # locales it defaults to the server encoding, so we have to specify it
    # explicitly
    my $el = ($locale eq 'C') ? '' : "set client_encoding='latin1'; ";
    is_program_out 'postgres', "echo '$el select * from t' | psql -Atq latin1test",
        0, "A\xF6B\n", 'upgraded latin1test DB has correctly encoded string';

    is ((exec_as 'postgres', 'psql -Atl', $outref), 0, 'psql -Atl on upgraded cluster');
    if ($locale eq 'C') {
        # verify ownership; encodings should be retained in C
        ok ((index $$outref, 'latin1test|latin1user|LATIN1') >= 0, 
            'latin1test is owned by latin1user and is LATIN1 encoded');
        ok ($$outref =~ qr/^utf8test\|utf8user\|(UTF8|UNICODE)$/m, 
            'utf8test is owned by utf8user and is UTF8 encoded');
    } else {
        # verify ownership; encodings have been corrected on upgrade
        ok ((index $$outref, 'latin1test|latin1user') >= 0, 'latin1user is owned by latin1test');
        ok ((index $$outref, 'utf8test|utf8user') >= 0, 'utf8user is owned by utf8test');
    }

    is ((system "pg_dropcluster --stop $newv main"), 0, 'dropping upgraded cluster');
}

test_upgrade 'C';
test_upgrade 'ru_RU.UTF-8';

check_clean;

# vim: filetype=perl
