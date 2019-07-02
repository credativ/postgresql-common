# check if pg_virtualenv runs ok, even under fakeroot

use strict;
use warnings;

use lib 't';
use TestLib;

use Test::More tests => 20;

my $virtualenv = 'pg_virtualenv sh -c \'echo "id|$(id -un)"; psql -AtXxc "SELECT current_user"\'';

$ENV{USER} = 'root';
like_program_out 'root',     $virtualenv, 0, qr!id.root\ncurrent_user.postgres!,     "running pg_virtualenv as root";
$ENV{USER} = 'postgres';
like_program_out 'postgres', $virtualenv, 0, qr!id.postgres\ncurrent_user.postgres!, "running pg_virtualenv as postgres";
$ENV{USER} = 'nobody';
like_program_out 'nobody',   $virtualenv, 0, qr!id.nobody\ncurrent_user.nobody!,     "running pg_virtualenv as nobody";

SKIP: {
    skip "No fakeroot tests on RedHat", 6 if $PgCommon::rpm;
    $ENV{USER} = 'root';
    like_program_out 'root',     "fakeroot $virtualenv", 0, qr!id.root\ncurrent_user.postgres!, "running fakeroot pg_virtualenv as root";
    $ENV{USER} = 'postgres';
    like_program_out 'postgres', "fakeroot $virtualenv", 0, qr!id.root\ncurrent_user.postgres!, "running fakeroot pg_virtualenv as postgres";
    $ENV{USER} = 'nobody';
    like_program_out 'nobody',   "fakeroot $virtualenv", 0, qr!id.root\ncurrent_user.nobody!,   "running fakeroot pg_virtualenv as nobody";
}

check_clean;

# vim: filetype=perl
