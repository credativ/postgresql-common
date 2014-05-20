# We try to call psql with --version and then on localhost. Since there are no
# clusters, we expect an error message that the connection to port 5432 is
# refused. This checks that pg_wrapper correctly picks the default port and
# uses the highest available version.

use strict;
use Test::More tests => 14;

use lib 't';
use TestLib;

like_program_out 0, 'psql --version', 0, qr/^psql \(PostgreSQL\) $ALL_MAJORS[-1]/, 
    'pg_wrapper selects highest available version number';

like_program_out 0, 'env LC_MESSAGES=C psql -h 127.0.0.1 -l', 2, qr/could not connect/, 
    'connecting to localhost fails with no clusters';

# We check if PGCLUSTER, --cluster, and native psql options are evaluated with
# correct priority. (This is related to the checks in t/090_multicluster.t, but
# easier to do here because no clusters are running.)

like_program_out 0, "env LC_MESSAGES=C PGCLUSTER=$MAJORS[-1]/127.0.0.2:5431 psql -l",
    2, qr/could not connect.*127.0.0.2.*on port 5431/s, 'pg_wrapper uses host and port from PGCLUSTER';
like_program_out 0, "env LC_MESSAGES=C PGCLUSTER=$MAJORS[-1]/127.0.0.2:5431 psql --cluster $MAJORS[-1]/127.0.0.3:5430 -l",
    2, qr/could not connect.*127.0.0.3.*on port 5430/s, 'pg_wrapper uses --cluster from the command line';
like_program_out 0, "env LC_MESSAGES=C PGCLUSTER=$MAJORS[-1]/127.0.0.2:5431 psql -h 127.0.0.3 -l",
    2, qr/could not connect.*127.0.0.3.*on port 5432/s, 'pg_wrapper ignores PGCLUSTER with -h on the command line';
like_program_out 0, "env LC_MESSAGES=C PGCLUSTER=$MAJORS[-1]/127.0.0.2:5431 psql --host 127.0.0.3 -l",
    2, qr/could not connect.*127.0.0.3.*on port 5432/s, 'pg_wrapper ignores PGCLUSTER with --host on the command line';
like_program_out 0, "env LC_MESSAGES=C PGCLUSTER=$MAJORS[-1]/127.0.0.2:5431 PGHOST=127.0.0.3 psql -l",
    2, qr/could not connect.*127.0.0.3.*on port 5432/s, 'pg_wrapper ignores PGCLUSTER if PGHOST is set';

# vim: filetype=perl
