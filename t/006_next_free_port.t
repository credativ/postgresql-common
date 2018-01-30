# Check PgCommon's next_free_port()

use strict; 

use lib '.';
use PgCommon;

use lib 't';
use TestLib;

use Test::More tests => $PgCommon::rpm ? 1 : 5;

# test next_free_port(). We are intentionally using nc as an external tool,
# using perl would replicate what next_free_port is doing, and that would
# be a pointless test.
use IPC::Open2;
use Time::HiRes qw(usleep);
my @pids;
# no ports open
is (next_free_port, 5432, 'next_free_port is 5432');

# open a localhost ipv4 socket
push @pids, open2(\*CHLD_OUT, \*CHLD_IN, qw(nc -4 -l 127.0.0.1 5432));
usleep 2*$delay;
is (next_free_port, 5433, 'next_free_port detects localhost ipv4 socket');
# open a wildcard ipv4 socket
push @pids, open2(\*CHLD_OUT, \*CHLD_IN, qw(nc -4 -l 5433));
usleep $delay;
is (next_free_port, 5434, 'next_free_port detects wildcard ipv4 socket');

SKIP: {
    $^V =~ /^v(\d+\.\d+)/; # parse perl version
    skip "perl <= 5.10 does not have proper IPv6 support", 2 if ($1 <= 5.10);
    skip "skipping IPv6 tests", 2 if ($ENV{SKIP_IPV6});

    # open a localhost ipv6 socket
    push @pids, open2(\*CHLD_OUT, \*CHLD_IN, qw(nc -6 -l ::1 5434));
    usleep $delay;
    is (next_free_port, 5435, 'next_free_port detects localhost ipv6 socket');
    # open a wildcard ipv6 socket
    push @pids, open2(\*CHLD_OUT, \*CHLD_IN, qw(nc -6 -l 5435));
    usleep $delay;
    is (next_free_port, 5436, 'next_free_port detects wildcard ipv6 socket');
}

# clean up
kill 15, @pids;

# vim: filetype=perl
