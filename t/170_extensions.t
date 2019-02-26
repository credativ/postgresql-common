# Check that all extensions install successfully.

use strict; 

use lib 't';
use TestLib;
use PgCommon;
use Test::More 0.87; # needs libtest-simple-perl backport on lenny

foreach my $v (@MAJORS) {
note "Running tests for $v";

if ($v < '9.1') {
    pass 'No extensions for version < 9.1';
    next;
}

# create cluster
is ((system "pg_createcluster $v main --start >/dev/null"), 0, "pg_createcluster $v main");

# plpgsql is installed by default; remove it to simplify test logic
is_program_out 'postgres', "psql -qc 'DROP EXTENSION plpgsql'", 0, '';
is_program_out 'postgres', "psql -Atc 'SELECT * FROM pg_extension'", 0, '';

my %depends = (
    earthdistance     => [qw(cube)],
    hstore_plperl     => [qw(hstore plperl)],
    hstore_plperlu    => [qw(hstore plperlu)],
    hstore_plpython2u => [qw(hstore plpython2u)],
    hstore_plpython3u => [qw(hstore plpython3u)],
    hstore_plpythonu  => [qw(hstore plpythonu)],
    jsonb_plperl      => [qw(plperl)],     # PG 11
    jsonb_plperlu     => [qw(plperlu)],    # PG 11
    jsonb_plpython2u  => [qw(plpython2u)], # PG 11
    jsonb_plpython3u  => [qw(plpython3u)], # PG 11
    jsonb_plpythonu   => [qw(plpythonu)],  # PG 11
    ltree_plpython2u  => [qw(ltree plpython2u)],
    ltree_plpython3u  => [qw(ltree plpython3u)],
    ltree_plpythonu   => [qw(ltree plpythonu)],
    # external extensions that might happen to be installed
    db2fce            => [qw(plpgsql)],
    pldbgapi          => [qw(plpgsql)],
    unit              => [qw(plpgsql)],
);

foreach (</usr/share/postgresql/$v/extension/*.control>) {
    my ($extname) = $_ =~ /^.*\/(.*)\.control$/;

    my $expected_extensions = "$extname\n";

    if ($depends{$extname}) {
        for my $dep (@{$depends{$extname}}) {
            is_program_out 'postgres', "psql -qc 'CREATE EXTENSION $dep'", 0, '',
                "$extname dependency $dep installs without error";
        }
        $expected_extensions = join ("\n", sort ($extname, @{$depends{$extname}})) . "\n";
    }

    if ($extname eq 'hstore' && $v eq '9.1') {
	# EXFAIL: hstore in 9.1 throws a warning about obsolete => operator
	like_program_out 'postgres', "psql -qc 'CREATE EXTENSION \"$extname\"'", 0,
	   qr/=>/, "extension $extname installs (with warning)";
    } elsif ($extname eq 'chkpass' && $v >= '9.5') {
        # chkpass is slightly broken, see
        # http://www.postgresql.org/message-id/20141117162116.GA3565@msg.df7cb.de
        like_program_out 'postgres', "psql -qc 'CREATE EXTENSION \"$extname\"'", 0,
            qr/WARNING:  type input function chkpass_in should not be volatile/,
            "extension $extname installs (with warning)";
    } else {
	is_program_out 'postgres', "psql -qc 'CREATE EXTENSION \"$extname\"'", 0, '',
	    "extension $extname installs without error";
    }

    is_program_out 'postgres', "psql -Atc 'SELECT extname FROM pg_extension ORDER BY extname'", 0,
	$expected_extensions, "$extname is in pg_extension";
    is_program_out 'postgres', "psql -qc 'DROP EXTENSION \"$extname\"'", 0, '',
	"extension $extname removes without error";

    if ($depends{$extname}) {
        for my $dep (@{$depends{$extname}}) {
            is_program_out 'postgres', "psql -qc 'DROP EXTENSION $dep'", 0, '',
                "$extname dependency extension $dep removes without error";
        }
    }
}

# clean up
is ((system "pg_dropcluster $v main --stop"), 0, "pg_dropcluster $v main");
check_clean;
}

done_testing();

# vim: filetype=perl
