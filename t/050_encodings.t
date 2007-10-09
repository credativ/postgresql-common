# Test locale and encoding settings in pg_createcluster.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => ($#MAJORS+1) * 87 + 10;

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
	is ((system "pg_createcluster --start --locale=$locale $v $cluster_name >/dev/null 2>&1"), 0,
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

    # create a table and stuff some ISO-8859-5 characters into it (для)
    is ((exec_as 'postgres', "createdb test", $outref), 0, 'creating test database');
    is_program_out 'postgres', "printf '\324\333\357' | psql -c \"set client_encoding='iso-8859-5'; 
	create table t (x varchar); copy t from stdin\" test", 0, '',
	'creating table with ISO-8859-5 characters';
    is_program_out 'postgres', "echo \"set client_encoding='utf8'; select * from t\" | psql -Atq test", 0,
	"\320\264\320\273\321\217\n", 'correct string in UTF-8';
    is_program_out 'postgres', "echo \"set client_encoding='iso-8859-5'; select * from t\" | psql -Atq test", 0,
	"\324\333\357\n", 'correct string in ISO-8859-5';

    # do the same test with using UTF-8 as input
    is_program_out 'postgres', "printf '\320\264\320\273\321\217' | psql -qc \"set client_encoding='utf8'; 
	delete from t; copy t from stdin\" test", 0, '',
	'creating table with UTF-8 characters';
    is_program_out 'postgres', "echo \"set client_encoding='utf8'; select * from t\" | psql -Atq test", 0,
	"\320\264\320\273\321\217\n", 'correct string in UTF-8';
    is_program_out 'postgres', "echo \"set client_encoding='iso-8859-5'; select * from t\" | psql -Atq test", 0,
	"\324\333\357\n", 'correct string in ISO-8859-1';

    # check encoding of server error messages (breaks in locale/encoding mismatches, so skip that)
    if (!defined $enc) {
	like_program_out 'postgres', 'psql test -c "set client_encoding = \'UTF-8\'; select sqrt(-1)"', 1,
	    qr/^[^?]*брать[^?]*$/, 'Server error message has correct language and encoding';
    }

    # check that we do not run into 'ignoring unconvertible UTF-8 character'
    # breakage on nonmatching lc_messages and client_encoding
    PgCommon::set_conf_value $v, $cluster_name, 'postgresql.conf',
	'client_encoding', 'UTF-8';
    PgCommon::set_conf_value $v, $cluster_name, 'postgresql.conf',
	'lc_messages', 'POSIX';
    is_program_out 0, "pg_ctlcluster $v $cluster_name restart", 0, '', 
	'cluster starts correctly with nonmatching lc_messages and client_encoding';

    # check interception of invalidly encoded/escaped strings
    if ($is_unicode) {
	like_program_out 'postgres', 
	    'printf "set client_encoding=\'UTF-8\'; select \'\\310\\\\\'a\'" | psql -Atq template1',
	    0, qr/(UNICODE|UTF8).*0xc85c/,
	    'Server rejects incorrect encoding (CVE-2006-2313)';
	like_program_out 'postgres', 
	    'printf "set client_encoding=\'SJIS\'; select \'\\\\\\\'a\'" | psql -Atq template1',
	    0, qr/\\' is insecure/,
	    'Server rejects \\\' escaping in unsafe client encoding (CVE-2006-2314)';
	my $esc_warning = ($v ge '8.1') ? "set escape_string_warning='off';" : '';
	is_program_out 'postgres', 
	    "printf \"set client_encoding='UTF-8'; $esc_warning select '\\\\\\'a'\" | psql -Atq template1",
		0, "'a\n", 'Server accepts \\\' escaping in safe client encoding (CVE-2006-2314)';
    }

    # drop cluster
    is ((system "pg_dropcluster $v $cluster_name --stop"), 0, 'Dropping cluster');
}

foreach my $v (@MAJORS) {
    check_cluster $v, 'ru_RU';
    if ($v ge '8.3') {
        # 8.3+ checks locale/encoding consistency, so use a matching one here
        check_cluster $v, 'ru_RU.UTF-8', 'UTF-8';
    } else {
        # up to 8.2, locale and encoding can mismatch
        check_cluster $v, 'ru_RU', 'UTF-8';
    }
    check_cluster $v, 'ru_RU.UTF-8';

    # check LC_* over LANG domination
    is ((system "LANGUAGE= LC_ALL=C LANG=bo_GUS.UTF-8 pg_createcluster --start $v main >/dev/null 2>&1"), 0,
            "pg_createcluster: LC_ALL dominates LANG");
    my $outref;
    is ((exec_as 'postgres', "/usr/lib/postgresql/$v/bin/pg_controldata /var/lib/postgresql/$v/main",
	    $outref), 0, 'pg_controldata succeeded on cluster');
    like $$outref, qr/LC_COLLATE:\s*C\s/, 'LC_COLLATE is correct';
    like $$outref, qr/LC_CTYPE:\s*C\s/, 'LC_CTYPE is correct';
    is ((system "pg_dropcluster $v main --stop"), 0, 'Dropping cluster');
}

check_clean;

# vim: filetype=perl
