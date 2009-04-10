# We try to call psql with --version and then on localhost. Since there are no
# clusters, we expect an error message that the connection to port 5432 is
# refused. This checks that pg_wrapper correctly picks the default port and
# uses the highest available version.

use strict;
use Test::More tests => 4;

use lib 't';
use TestLib;

like_program_out 0, 'psql --version', 0, qr/^psql \(PostgreSQL\) $MAJORS[-1]/, 
    'pg_wrapper selects highest available version number';

like_program_out 0, 'env LC_MESSAGES=C psql -h 127.0.0.1 -l', 2, qr/could not connect/, 
    'connecting to localhost fails with no clusters';

# vim: filetype=perl
