use strict;

use lib 't';
use TestLib;
use PgCommon;

use Test::More;

my ($pg_uid, $pg_gid) = (getpwnam 'postgres')[2,3];

foreach my $v (@MAJORS) {
    note "PostgreSQL $v";

    note "create cluster";
    program_ok 0, "pg_createcluster --locale C.UTF-8 $v main --start";
    like_program_out 0, "pg_lsclusters -h", 0, qr/$v main 5432 online/;
    program_ok 0, "pg_conftool $v main set work_mem 11MB";
    program_ok $pg_uid, "createdb -E SQL_ASCII -T template0 mydb";
    program_ok $pg_uid, "psql -c 'alter database mydb set search_path=public'";
    program_ok $pg_uid, "psql -c 'create table foo (t text)' mydb";
    program_ok $pg_uid, "psql -c \"insert into foo values ('important data')\" mydb";
    program_ok $pg_uid, "createuser myuser";
    program_ok $pg_uid, "psql -c 'alter role myuser set search_path=public, myschema'";
    SKIP: { # in PG 10, AR-ID is part of globals.sql which we try to restore before databases.sql
        skip "alter role in database handling in PG <= 10 not supported", 1 if ($v <= 10);
        program_ok $pg_uid, "psql -c 'alter role myuser in database mydb set search_path=public, myotherschema'";
    }

    note "create directory";
    program_ok 0, "pg_backupcluster $v main createdirectory";
    my $dir = "/var/backups/postgresql/$v-main";
    my @stat = stat $dir;
    is $stat[4], $pg_uid, "$dir owned by uid postgres";
    is $stat[5], $pg_gid, "$dir owned by gid postgres";

    note "dump";
    program_ok 0, "pg_backupcluster $v main dump";
    my $dump = glob "$dir/*.dump";
    @stat = stat $dump;
    is $stat[4], $pg_uid, "$dump owned by uid postgres";
    is $stat[5], $pg_gid, "$dump owned by gid postgres";

    note "basebackup";
    program_ok 0, "pg_backupcluster $v main basebackup";
    my $basebackup = glob "$dir/*.backup";
    @stat = stat $basebackup;
    is $stat[4], $pg_uid, "$basebackup owned by uid postgres";
    is $stat[5], $pg_gid, "$basebackup owned by gid postgres";

    note "list";
    like_program_out 0, "pg_backupcluster $v main list", 0, qr/$dump.*$basebackup/s;

    for my $backup ($dump, $basebackup) {
        note "restore $backup";
        program_ok 0, "pg_dropcluster $v main --stop";
        program_ok 0, "pg_restorecluster $v main $backup --start";
        is_program_out $pg_uid, "psql -XAtl", 0, "mydb|postgres|SQL_ASCII|C.UTF-8|C.UTF-8|
postgres|postgres|UTF8|C.UTF-8|C.UTF-8|
template0|postgres|UTF8|C.UTF-8|C.UTF-8|=c/postgres
postgres=CTc/postgres
template1|postgres|UTF8|C.UTF-8|C.UTF-8|=c/postgres
postgres=CTc/postgres\n";
        is_program_out $pg_uid, "psql -XAtc 'show work_mem'", 0, "11MB\n";
        is_program_out $pg_uid, "psql -XAtc 'select * from foo' mydb", 0, "important data\n";
        is_program_out $pg_uid, "psql -XAtc \"select analyze_count from pg_stat_user_tables where relname = 'foo'\" mydb", 0, "3\n"; # --analyze-in-stages does 3 passes
        SKIP: {
            skip "alter role in database handling in PG <= 10 not supported", 1 if ($v <= 10);
            is_program_out $pg_uid, "psql -XAtc '\\drds'", 0, "myuser|mydb|search_path=public, myotherschema
myuser||search_path=public, myschema
|mydb|search_path=public\n";
        }
    }

    program_ok 0, "pg_dropcluster $v main --stop";
    check_clean;

} # foreach version

done_testing();

# vim: filetype=perl
