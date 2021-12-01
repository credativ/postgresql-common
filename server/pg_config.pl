#!/usr/bin/perl

# Perl reimplementation of PostgreSQL's pg_config binary.
# We provide this as /usr/bin/pg_config to support cross-compilation using
# libpq-dev. Also, this makes the two installed pg_config copies not conflict
# via their debugging symbols.
#
# This code is released under the terms of the PostgreSQL License.
# Portions Copyright (c) 1996-2017, PostgreSQL Global Development Group
# Author: Christoph Berg

use strict;
use warnings;

# no arguments, print all items
if (@ARGV == 0) {
	while (<DATA>) {
		last if /^$/; # begin of help section
		print;
	}
	exit 0;
}

# --help or -?
if (grep {$_ =~ /^(--help|-\?)$/} @ARGV) {
	while (<DATA>) {
		last if /^$/; # begin of help section
	}
	print; # include empty line in output
	while (<DATA>) {
		next if /^Report bugs/; # Skip bug address in the perl version
		print;
	}
	exit 0;
}

# specific value(s) requested
my %options;
my $help;
while (<DATA>) {
	last if /^$/; # begin of help section
	/^(\S+) = (.*)/ or die "malformatted data item";
	$options{'--' . lc $1} = $2;
}

foreach my $arg (@ARGV) {
	unless ($options{$arg}) {
		print "pg_config: invalid argument: $arg\n";
		print "Try \"pg_config --help\" for more information.\n";
		exit 1;
	}
	print "$options{$arg}\n";
}

exit 0;

# The DATA section consists of the `pg_config` output (one KEY = value item per
# line), and the `pg_config --help` text. The first --help line is empty, which
# we use to detect the beginning of the help section.

__DATA__
INCLUDEDIR = /usr/include/postgresql

pg_config provides information about the installed version of PostgreSQL.

Usage:
  pg_config [OPTION]...

Options:
  --includedir          show location of C header files of the client
                        interfaces
  -?, --help            show this help, then exit

With no arguments, all known items are shown.

Report bugs to <pgsql-bugs@postgresql.org>.
