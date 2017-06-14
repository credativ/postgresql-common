# Check that no clusters and postgres processes are present for this test.

use strict;
use Test::More tests => 8;

use lib 't';
use TestLib;

check_clean;

# vim: filetype=perl
