# Check that ecpg works

use strict; 

use lib 't';
use TestLib;

use Test::More tests => 19;

use lib '/usr/share/postgresql-common';
use PgCommon;

my $v = $MAJORS[-1];

# prepare nobody-owned work dir
my $workdir=`su -c 'mktemp -d' nobody`;
chomp $workdir;
chdir $workdir or die "could not chdir to $workdir: $!";

# create test code
open F, '>test.pgc' or die "Could not open $workdir/test.pgc: $!";
print F <<EOF;
#include <stdio.h>

EXEC SQL BEGIN DECLARE SECTION;
    char output[1024];
EXEC SQL END DECLARE SECTION;

int main() {
    EXEC SQL CONNECT TO template1;
    EXEC SQL SELECT current_database() INTO :output;
    puts(output);
    EXEC SQL DISCONNECT ALL;
    return 0;
}
EOF
close F;
chmod 0644, 'test.pgc';

is_program_out 'nobody', 'ecpg test.pgc', 0, '', 'ecpg processing';

is_program_out 'nobody', 'cc -I /usr/include/postgresql/ -o test test.c -lecpg', 
    0, '', 'compiling ecpg output';
chdir '/' or die "could not chdir to /: $!";

# create cluster
is ((system "pg_createcluster $v main --start >/dev/null"), 0, "pg_createcluster $v main");
is ((exec_as 'postgres', 'createuser nobody -D -R -S'), 0, 'createuser nobody');

is_program_out 'nobody', "$workdir/test", 0, "template1\n", 
    'runs and gives correct output';

# clean up
system "rm -rf $workdir";
is ((system "pg_dropcluster $v main --stop"), 0, "pg_dropcluster $v main");
check_clean;

# vim: filetype=perl
