#!/usr/bin/perl -w
# Check that no clusters, postmasters, and pg_autovacuum daemons are present
# for this test.

use strict;
use Test::More tests => 3;

use lib 't';
use TestLib;

is (`pg_lsclusters -h`, '', 'No existing clusters');
is ((ps 'postmaster'), '', 'No existing postmaster processes');
is ((ps 'pg_autovacuum'), '', 'No existing pg_autovacuum processes');

# vim: filetype=perl
