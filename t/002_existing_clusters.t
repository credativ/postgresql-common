# Check that no clusters and postmasters are present for this test.

use strict;
use Test::More tests => 10;

use lib 't';
use TestLib;

check_clean;

# vim: filetype=perl
