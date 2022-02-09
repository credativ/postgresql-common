# Check that ecpg works

use strict; 

use lib 't';
use TestLib;
use PgCommon;
use Test::More tests => 14;

my $v = $MAJORS[-1];

# prepare nobody-owned work dir
my $workdir=`su -s /bin/sh -c 'mktemp -d' nobody`;
chomp $workdir;
chdir $workdir or die "could not chdir to $workdir: $!";

# create test code
open F, '>test.pgc' or die "Could not open $workdir/test.pgc: $!";
print F <<EOF;
#include <stdio.h>
#include <stdlib.h>

EXEC SQL WHENEVER SQLWARNING SQLPRINT;
EXEC SQL WHENEVER SQLERROR SQLPRINT;

EXEC SQL BEGIN DECLARE SECTION;
    char output[1024];
EXEC SQL END DECLARE SECTION;

int main() {
    ECPGdebug(1, stderr);
    EXEC SQL CONNECT TO template1;
    EXEC SQL SELECT 'Database is ' || current_database() INTO :output;
    puts(output);
    EXEC SQL DISCONNECT ALL;
    return 0;
}
EOF
close F;
chmod 0644, 'test.pgc';

is_program_out 'nobody', 'ecpg test.pgc', 0, '', 'ecpg processing';

is_program_out 'nobody', 'cc -I$(pg_config --includedir) -L$(pg_config --libdir) -o test test.c -lecpg',
    0, '', 'compiling ecpg output';
chdir '/' or die "could not chdir to /: $!";

# run program
like_program_out 'nobody', "pg_virtualenv $workdir/test", 0, qr/Database is template1/,
    'test program runs and gives correct output';

# clean up
system "rm -rf $workdir";
check_clean;

# vim: filetype=perl
