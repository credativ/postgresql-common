# Test pg_conftool

use strict;
use warnings;

use Test::More tests => 41;
use File::Temp qw/tempdir/;
use lib '.';
use PgCommon;
use lib 't';
use TestLib;

my $tdir = tempdir (CLEANUP => 1);
$ENV{'PG_CLUSTER_CONF_ROOT'} = $tdir;

open F, "> $tdir/different.conf";
print F "a = '5'\n";
print F "#b = '6'\n";
close F;

note 'test without cluster';
is_program_out 0, "pg_conftool show all", 1, "Error: No default cluster found\n";
is_program_out 0, "pg_conftool foo.conf show all", 1, "Error: No default cluster found\n";
is_program_out 0, "pg_conftool $tdir/different.conf show all", 0, "a = 5\n";
is_program_out 0, "pg_conftool 9.7 main show all", 1, "Error: Cluster 9.7 main does not exist\n";

my $version = $MAJORS[-1];
die "Tests past this point need PostgreSQL installed" unless ($version);
mkdir "$tdir/$version";
mkdir "$tdir/$version/main";

open F, "> $tdir/$version/main/postgresql.conf";
print F "a = '1'\n";
print F "#b = '2'\n";
close F;

open F, "> $tdir/$version/main/other.conf";
print F "a = '3'\n";
print F "#b = '4'\n";
close F;

sub pgconf {
    undef $/;
    open F, "$tdir/$version/main/postgresql.conf";
    my $f = <F>;
    close F;
    return $f;
}

sub differentconf {
    undef $/;
    open F, "$tdir/different.conf";
    my $f = <F>;
    close F;
    return $f;
}

note 'test show';
is_program_out 0, "pg_conftool show all", 0, "a = 1\n";
is_program_out 0, "pg_conftool other.conf show all", 0, "a = 3\n";
is_program_out 0, "pg_conftool $tdir/different.conf show all", 0, "a = 5\n";
is_program_out 0, "pg_conftool $version main show all", 0, "a = 1\n";
is_program_out 0, "pg_conftool $version main other.conf show all", 0, "a = 3\n";
is_program_out 0, "pg_conftool show a", 0, "a = 1\n";
is_program_out 0, "pg_conftool -s show a", 0, "1\n";

note 'test set';
is_program_out 0, "pg_conftool set c 7", 0, "";
undef $/; # slurp mode
is pgconf, "a = '1'\n#b = '2'\nc = 7\n", "file contains new setting";
is_program_out 0, "pg_conftool set a 8", 0, "";
is pgconf, "a = 8\n#b = '2'\nc = 7\n", "file contains updated setting";
is_program_out 0, "pg_conftool $tdir/different.conf set a 9", 0, "";
is differentconf, "a = 9\n#b = '6'\n", "file with path contains updated setting";

note 'test remove';
is_program_out 0, "pg_conftool remove a", 0, "";
is pgconf, "#a = 8\n#b = '2'\nc = 7\n", "setting removed from file";
is_program_out 0, "pg_conftool $tdir/different.conf remove a", 0, "";
is differentconf, "#a = 9\n#b = '6'\n", "setting removed from file with path";

note 'test edit';
$ENV{EDITOR} = 'cat';
is_program_out 0, "pg_conftool edit", 0, "#a = 8\n#b = '2'\nc = 7\n";
is_program_out 0, "pg_conftool $tdir/different.conf edit", 0, "#a = 9\n#b = '6'\n";
