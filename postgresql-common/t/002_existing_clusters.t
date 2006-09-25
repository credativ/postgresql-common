# Check that no clusters, postmasters, and pg_autovacuum daemons are present
# for this test.

use strict;
use Test::More tests => 10;

use lib 't';
use TestLib;

check_clean;

# vim: filetype=perl
