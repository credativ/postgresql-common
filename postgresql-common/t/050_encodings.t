#!/usr/bin/perl -w
# Test locale and encoding settings in pg_createcluster.

use strict; 

use lib 't';
use TestLib;

use lib '/usr/share/postgresql-common';
use PgCommon;

use Test::More tests => 44;

# create a test cluster with given locale, check the locale/encoding, and
# remove it again (unless disabled)
# Arguments: <version> <locale> [<delete>] [<encoding>] 
sub check_cluster {
    my ($v, $locale, $del, $enc) = @_;
    my $cluster_name = $locale;
    if (defined $enc) {
	$cluster_name .= "_$enc";
	ok ((system "LC_ALL='$locale' pg_createcluster --encoding $enc --start $v $cluster_name >/dev/null 2>&1") == 0,
		"pg_createcluster for $locale with --encoding succeeded");
    } else {
	ok ((system "LC_ALL='$locale' pg_createcluster --start $v $cluster_name >/dev/null 2>&1") == 0,
		"pg_createcluster for $locale without --encoding succeeded");
    }

    # check cluster locale
    my $outref;
    is ((exec_as 'postgres', "/usr/lib/postgresql/$v/bin/pg_controldata /var/lib/postgresql/$v/$cluster_name",
	    $outref), 0, 'pg_controldata succeeded on cluster');
    like $$outref, qr/LC_COLLATE:\s*$locale\s/, 'LC_COLLATE is correct';
    like $$outref, qr/LC_CTYPE:\s*$locale\s/, 'LC_CTYPE is correct';

    # check encoding
    sleep 1;
    is ((exec_as 'postgres', "psql -Atl --cluster $v/$cluster_name", $outref), 0,
	'psql -l succeeds');
    my $is_unicode = 0;
    $is_unicode = 1 if defined $enc && $enc =~ /(UNICODE|UTF-8)/;
    $is_unicode = 1 if $locale =~ /UTF-8/;
    if ($is_unicode) {
	like $$outref, qr/template1.*(UNICODE|UTF8)/, 'template1 is UTF-8 encoded';
    } else {
	unlike $$outref, qr/template1.*(UNICODE|UTF8)/, 'template1 is not UTF-8 encoded';
    }

    # drop cluster again if requested
    if (defined $del) {
	ok ((system "pg_dropcluster $v $cluster_name --stop-server") == 0, 
	    'Dropping cluster');
    }
}

check_cluster $MAJORS[0], 'en_US', 1;
check_cluster $MAJORS[0], 'en_US', 1, 'UTF-8';
check_cluster $MAJORS[0], 'en_US.UTF-8', 1;

check_cluster $LATEST_MAJOR, 'en_US', 1;
check_cluster $LATEST_MAJOR, 'en_US', 1, 'UTF-8';
check_cluster $LATEST_MAJOR, 'en_US.UTF-8', 1;

# Check clusters
my $outref;
is ((exec_as 'postgres', 'pg_lsclusters -h', $outref), 0, 'pg_lsclusters succeeds');
is $$outref, '', 'empty pg_lsclusters output';

# vim: filetype=perl
