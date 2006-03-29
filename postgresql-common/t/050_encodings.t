# Test locale and encoding settings in pg_createcluster.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 6 * 20 + 7;

# create a test cluster with given locale, check the locale/encoding, and
# remove it
# Arguments: <version> <locale> [<encoding>] 
sub check_cluster {
    my ($v, $locale, $enc) = @_;
    my $cluster_name = $locale;
    if (defined $enc) {
	$cluster_name .= "_$enc";
	is ((system "LC_ALL='$locale' pg_createcluster --encoding $enc --start $v $cluster_name >/dev/null 2>&1"), 0,
		"pg_createcluster version $v for $locale with --encoding succeeded");
    } else {
	is ((system "LC_ALL='$locale' pg_createcluster --start $v $cluster_name >/dev/null 2>&1"), 0,
		"pg_createcluster version $v for $locale without --encoding succeeded");
    }

    # check cluster locale
    my $outref;
    is ((exec_as 'postgres', "/usr/lib/postgresql/$v/bin/pg_controldata /var/lib/postgresql/$v/$cluster_name",
	    $outref), 0, 'pg_controldata succeeded on cluster');
    like $$outref, qr/LC_COLLATE:\s*$locale\s/, 'LC_COLLATE is correct';
    like $$outref, qr/LC_CTYPE:\s*$locale\s/, 'LC_CTYPE is correct';

    # check encoding
    sleep 1;
    is ((exec_as 'postgres', "psql -Atl --cluster $v/$cluster_name", $outref, 0), 0,
	'psql -l succeeds');
    my $is_unicode = 0;
    $is_unicode = 1 if defined $enc && $enc =~ /(UNICODE|UTF-8)/;
    $is_unicode = 1 if $locale =~ /UTF-8/;
    if ($is_unicode) {
	like $$outref, qr/template1.*(UNICODE|UTF8)/, 'template1 is UTF-8 encoded';
    } else {
	unlike $$outref, qr/template1.*(UNICODE|UTF8)/, 'template1 is not UTF-8 encoded';
    }

    # create a table and stuff some ISO-8859-1 characters into it (äÖß¼)
    is ((exec_as 'postgres', "createdb test", $outref), 0, 'creating test database');
    is_program_out 'postgres', "/bin/echo -e '\344\326\337\274' | psql -c \"set client_encoding='latin1'; 
	create table t (x varchar); copy t from stdin\" test", 0, '',
	'creating table with ISO-8859-1 characters';
    is_program_out 'postgres', "echo \"set client_encoding='utf8'; select * from t\" | psql -Atq test", 0,
	"\303\244\303\226\303\237\302\274\n", 'correct string in UTF-8';
    is_program_out 'postgres', "echo \"set client_encoding='latin1'; select * from t\" | psql -Atq test", 0,
	"\344\326\337\274\n", 'correct string in ISO-8859-1';

    # do the same test with using UTF-8 as input
    is_program_out 'postgres', "echo 'äÖß¼' | psql -qc \"set client_encoding='utf8'; 
	delete from t; copy t from stdin\" test", 0, '',
	'creating table with UTF-8 characters';
    is_program_out 'postgres', "echo \"set client_encoding='utf8'; select * from t\" | psql -Atq test", 0,
	"\303\244\303\226\303\237\302\274\n", 'correct string in UTF-8';
    is_program_out 'postgres', "echo \"set client_encoding='latin1'; select * from t\" | psql -Atq test", 0,
	"\344\326\337\274\n", 'correct string in ISO-8859-1';

    # drop cluster
    is ((system "pg_dropcluster $v $cluster_name --stop-server"), 0, 'Dropping cluster');
}

check_cluster $MAJORS[0], 'en_US';
check_cluster $MAJORS[0], 'en_US', 'UTF-8';
check_cluster $MAJORS[0], 'en_US.UTF-8';

check_cluster $MAJORS[-1], 'en_US';
check_cluster $MAJORS[-1], 'en_US', 'UTF-8';
check_cluster $MAJORS[-1], 'en_US.UTF-8';

check_clean;

# vim: filetype=perl
