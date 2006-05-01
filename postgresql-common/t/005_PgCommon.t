# Check PgCommon library functions.

use strict; 

use File::Temp qw/tempdir/;

#use lib '/usr/share/postgresql-common';
use lib '..';
use PgCommon;

use lib 't';
use TestLib;

use Test::More tests => 18;

my $tdir = tempdir (CLEANUP => 1);

# test read_pg_hba with valid file
open P, ">$tdir/pg_hba.conf" or die "Could not create $tdir/pg_hba.conf: $!";
print P <<EOF;
# comment
local all postgres ident sameuser

# TYPE DATABASE USER CIDR-ADDRESS METHOD
local foo nobody trust
local foo nobody crypt
local foo nobody krb5
local foo nobody ident
local all all	 password
host      all all 127.0.0.1/32		  md5
hostssl   all all 192.168.0.0 255.255.0.0 pam
hostnossl all all 192.168.0.0 255.255.0.0 reject
EOF
close P;

my @expected_records = (
  { 'type' => 'local', 'db' => 'all', 'user' => 'postgres', 'method' => 'ident sameuser' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'trust' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'crypt' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'krb5' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'ident' },
  { 'type' => 'local', 'db' => 'all', 'user' => 'all', 'method' => 'password' },
  { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'method' => 'md5', 'ip' => '127.0.0.1', 'mask' => '32'},
  { 'type' => 'hostssl', 'db' => 'all', 'user' => 'all', 'method' => 'pam', 'ip' => '192.168.0.0', 'mask' => '255.255.0.0'},
  { 'type' => 'hostnossl', 'db' => 'all', 'user' => 'all', 'method' => 'reject', 'ip' => '192.168.0.0', 'mask' => '255.255.0.0'},
);

my @hba = read_pg_hba "$tdir/pg_hba.conf";
foreach my $entry (@hba) {
    next if $$entry{'type'} eq 'comment';
    if ($#expected_records < 0) {
	fail '@expected_records is already empty';
	next;
    }
    my $expected = shift @expected_records;
    my $parsedstr = '';
    my $expectedstr = '';
    foreach my $k (keys %$expected) {
	$parsedstr .= $k . ':\'' . $$entry{$k} . '\' '; 
	$expectedstr .= $k . ':\'' . $$expected{$k} . '\' '; 
	if ($$expected{$k} ne $$entry{$k}) {
	    fail "mismatch: $expectedstr ne $parsedstr";
	    last;
	}
    }
    pass 'correctly parsed line \'' . $$entry{'line'} . "'";
}

ok (($#expected_records == -1), '@expected_records has correct number of entries');

# test read_pg_hba with invalid file
my $invalid_hba = <<EOF;
foo   all all md5
local all all foo
host  all all foo
host  all all 127.0.0.1/32 foo
host  all all md5
host  all all 127.0.0.1/32 0.0.0.0 md5
host  all all 127.0.0.1 md5
EOF
open P, ">$tdir/pg_hba.conf" or die "Could not create $tdir/pg_hba_invalid.conf: $!";
print P $invalid_hba;
close P;

@hba = read_pg_hba "$tdir/pg_hba.conf";
is (scalar (split "\n", $invalid_hba), $#hba+1, 'returned read_pg_hba array has correct number of records');
foreach my $entry (@hba) {
    is $$entry{'type'}, undef, 'line \'' . $$entry{'line'} . '\' parsed as invalid';
}

# vim: filetype=perl
