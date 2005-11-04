#!/usr/bin/perl -w
# We try to call psql with --version and then on localhost. Since there are no
# clusters, we expect an error message that the connection to port 5432 is
# refused. This checks that pg_wrapper correctly picks the default port and
# uses the highest available version.

use strict;
use Test::More tests => 4;

use lib 't';
use TestLib;

open (OUT, '-|', 'psql', '--version') or die "call psql: $!";
$_ = <OUT>;
my @F = split;
is ($F[-1], '8.0.4', 'pg_wrapper selects highest available version number');
close OUT;
is ($?, 0, 'psql --version exits successfully'); # check exit code

close STDERR;
open (OUT, '-|', 'psql', '-h', '127.0.0.1', '-l') or die "call psql: $!";
<OUT>;
@F = split;
ok ($F[-1] =~ /8\.0\.\d+/, 'pg_wrapper selects highest available version number');
close OUT;
is ($? >> 8, 2, 'connecting to localhost fails with no clusters'); # check failure exit code

# vim: filetype=perl
