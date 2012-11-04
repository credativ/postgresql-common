# Check that all extensions install successfully.

use strict; 

use lib 't';
use TestLib;

use Test::More 0.87; # needs libtest-simple-perl backport on lenny

use lib '/usr/share/postgresql-common';
use PgCommon;

my $v = $MAJORS[-1];

if ($v < '9.1') {
    pass 'No extensions for version < 9.1';
    done_testing(1);
    exit 0;
}

# create cluster
is ((system "pg_createcluster $v main --start >/dev/null"), 0, "pg_createcluster $v main");

# plpgsql is installed by default; remove it to simplify test logic
is_program_out 'postgres', "psql -qc 'DROP EXTENSION plpgsql'", 0, '';
is_program_out 'postgres', "psql -Atc 'SELECT * FROM pg_extension'", 0, '';

foreach (</usr/share/postgresql/$v/extension/*.control>) {
    my ($extname) = $_ =~ /^.*\/(.*)\.control$/;

    my $expected_extensions = "$extname\n";

    if ($extname eq 'earthdistance') {
	# depends on cube
	is_program_out 'postgres', "psql -qc 'CREATE EXTENSION cube'", 0, '',
	    "dependency cube installs without error";
	$expected_extensions = "cube\n" . $expected_extensions;
    }

    if ($extname eq 'hstore' && $v eq '9.1') {
	# EXFAIL: hstore in 9.1 throws a warning about obsolete => operator
	like_program_out 'postgres', "psql -qc 'CREATE EXTENSION \"$extname\"'", 0,
	   qr/=>/, "extension $extname installs (with warning)";
    } else {
	is_program_out 'postgres', "psql -qc 'CREATE EXTENSION \"$extname\"'", 0, '',
	    "extension $extname installs without error";
    }

    is_program_out 'postgres', "psql -Atc 'SELECT extname FROM pg_extension'", 0, 
	$expected_extensions, "$extname is in pg_extension";
    is_program_out 'postgres', "psql -qc 'DROP EXTENSION \"$extname\"'", 0, '',
	"extension $extname removes without error";
    if ($extname eq 'earthdistance') {
	is_program_out 'postgres', "psql -qc 'DROP EXTENSION cube'", 0, '',
	    "dependency extension cube removes without error";
    }
}

# clean up
is ((system "pg_dropcluster $v main --stop"), 0, "pg_dropcluster $v main");
check_clean;

done_testing();

# vim: filetype=perl
