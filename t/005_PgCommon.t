# Check PgCommon library functions.

use strict; 

use File::Temp qw/tempdir/;

use lib '.';
use PgCommon;

use lib 't';
use TestLib;

use Test::More tests => 24;

my $tdir = tempdir (CLEANUP => 1);
$PgCommon::confroot = $tdir;

# test read_pg_hba with valid file
open P, ">$tdir/pg_hba.conf" or die "Could not create $tdir/pg_hba.conf: $!";
print P <<EOF;
# comment
local all postgres ident sameuser

# TYPE DATABASE USER CIDR-ADDRESS METHOD
local foo nobody trust
local foo nobody crypt
local foo nobody,joe krb5
local foo,bar nobody ident
local all +foogrp	 password
host \@inc all 127.0.0.1/32	md5
hostssl   all \@inc 192.168.0.0 255.255.0.0 pam
hostnossl all all 192.168.0.0 255.255.0.0 reject
EOF
close P;

my @expected_records = (
  { 'type' => 'local', 'db' => 'all', 'user' => 'postgres', 'method' => 'ident sameuser' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'trust' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody', 'method' => 'crypt' },
  { 'type' => 'local', 'db' => 'foo', 'user' => 'nobody,joe', 'method' => 'krb5' },
  { 'type' => 'local', 'db' => 'foo,bar', 'user' => 'nobody', 'method' => 'ident' },
  { 'type' => 'local', 'db' => 'all', 'user' => '+foogrp', 'method' => 'password' },
  { 'type' => 'host', 'db' => '@inc', 'user' => 'all', 'method' => 'md5', 'ip' => '127.0.0.1', 'mask' => '32'},
  { 'type' => 'hostssl', 'db' => 'all', 'user' => '@inc', 'method' => 'pam', 'ip' => '192.168.0.0', 'mask' => '255.255.0.0'},
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

# test read_conf_file()
my %conf = PgCommon::read_conf_file '/nonexisting';
is_deeply \%conf, {}, 'read_conf_file returns empty dict for nonexisting file';

mkdir "$tdir/8.4";
mkdir "$tdir/8.4/test" or die "mkdir: $!";
my $c = "$tdir/8.4/test/foo.conf";
open F, ">$c" or die "Could not create $c: $!";
print F <<EOF;
# test configuration file

# Commented_Int = 12
# commented_str='foobar'

#intval = 1
Intval = 42
cintval=1 # blabla
strval 'hello'
strval2 'world'
cstrval = 'bye' # comment
emptystr = ''
cemptystr = '' # moo!
#testpath = '/bin/bad'
testpath = '/bin/test'
QuoteStr = 'test ! -f \\'/tmp/%f\\' && echo \\'yes\\''
EOF
close F;
%conf = PgCommon::read_conf_file "$c";
is_deeply (\%conf, {
      'intval' => 42, 
      'cintval' => 1, 
      'strval' => 'hello', 
      'strval2' => 'world', 
      'cstrval' => 'bye', 
      'testpath' => '/bin/test', 
      'emptystr' => '',
      'cemptystr' => '',
      'quotestr' => "test ! -f '/tmp/%f' && echo 'yes'"
    }, 'read_conf_file() parsing');

# test read_conf_file() with include directives
open F, ">$tdir/8.4/test/condinc.conf" or die "Could not create $tdir/condinc.conf: $!";
print F "condint = 42\n";
close F;

open F, ">$tdir/bar.conf" or die "Could not create $tdir/bar.conf: $!";
print F <<EOF;
# test configuration file

# Commented_Int = 24
# commented_str = 'notme'

intval = -1
include '8.4/test/foo.conf'
strval = 'howdy'
include_if_exists '/nonexisting.conf'
include_if_exists '8.4/test/condinc.conf'
EOF
close F;

%conf = PgCommon::read_conf_file "$tdir/bar.conf";
is_deeply (\%conf, {
      'intval' => 42, 
      'cintval' => 1, 
      'strval' => 'howdy', 
      'strval2' => 'world', 
      'cstrval' => 'bye', 
      'testpath' => '/bin/test', 
      'emptystr' => '',
      'cemptystr' => '',
      'quotestr' => "test ! -f '/tmp/%f' && echo 'yes'",
      'condint' => 42,
    }, 'read_conf_file() parsing with include directives');


# test set_conf_value()
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'commented_int', '24';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'commented_str', 'new foo';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'intval', '39';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'cintval', '5';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'strval', 'Howdy';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'newval', 'NEW!';
PgCommon::set_conf_value '8.4', 'test', 'foo.conf', 'testpath', '/bin/new';

open F, "$c";
my $conf;
read F, $conf, 1024;
close F;
is ($conf, <<EOF, 'set_conf_value');
# test configuration file

Commented_Int = 24
commented_str='new foo'

#intval = 1
Intval = 39
cintval=5 # blabla
strval Howdy
strval2 'world'
cstrval = 'bye' # comment
emptystr = ''
cemptystr = '' # moo!
#testpath = '/bin/bad'
testpath = '/bin/new'
QuoteStr = 'test ! -f \\'/tmp/%f\\' && echo \\'yes\\''
newval = 'NEW!'
EOF

# test disable_conf_value()
PgCommon::disable_conf_value '8.4', 'test', 'foo.conf', 'intval', 'ints are out of fashion';
PgCommon::disable_conf_value '8.4', 'test', 'foo.conf', 'cstrval', 'not used any more';
PgCommon::disable_conf_value '8.4', 'test', 'foo.conf', 'nonexisting', 'NotMe';
PgCommon::disable_conf_value '8.4', 'test', 'foo.conf', 'testpath', 'now 2 comments';

open F, "$c";
read F, $conf, 1024;
close F;
is ($conf, <<EOF, 'disable_conf_value');
# test configuration file

Commented_Int = 24
commented_str='new foo'

#intval = 1
#Intval = 39 #ints are out of fashion
cintval=5 # blabla
strval Howdy
strval2 'world'
#cstrval = 'bye' # comment #not used any more
emptystr = ''
cemptystr = '' # moo!
#testpath = '/bin/bad'
#testpath = '/bin/new' #now 2 comments
QuoteStr = 'test ! -f \\'/tmp/%f\\' && echo \\'yes\\''
newval = 'NEW!'
EOF

# test replace_conf_value()
PgCommon::replace_conf_value '8.4', 'test', 'foo.conf', 'strval',
    'renamedstrval', 'newstrval', 'goodbye';
PgCommon::replace_conf_value '8.4', 'test', 'foo.conf', 'nonexisting',
    'renamednonexisting', 'newnonexisting', 'XXX';

open F, "$c";
read F, $conf, 1024;
close F;
is ($conf, <<EOF, 'replace_conf_value');
# test configuration file

Commented_Int = 24
commented_str='new foo'

#intval = 1
#Intval = 39 #ints are out of fashion
cintval=5 # blabla
#strval Howdy #renamedstrval
newstrval = goodbye
strval2 'world'
#cstrval = 'bye' # comment #not used any more
emptystr = ''
cemptystr = '' # moo!
#testpath = '/bin/bad'
#testpath = '/bin/new' #now 2 comments
QuoteStr = 'test ! -f \\'/tmp/%f\\' && echo \\'yes\\''
newval = 'NEW!'
EOF

# vim: filetype=perl
