# Check for proper ENOSPC handling

use strict;

require File::Temp;

use lib 't';
use TestLib;
use Test::More tests => 26;

my $outref;

# check that a failed pg_createcluster leaves no cruft behind: try creating a
# cluster on a 10 MB tmpfs
my $cmd = <<EOF;
exec 2>&1
set -e
mount --make-rprivate / 2> /dev/null || :
mkdir -p /var/lib/postgresql
trap "umount /var/lib/postgresql" 0 HUP INT QUIT ILL ABRT PIPE TERM
mount -t tmpfs -o size=10000000 none /var/lib/postgresql
# this is supposed to fail
LC_MESSAGES=C pg_createcluster $MAJORS[-1] test && exit 1 || true
echo -n "ls>"
# should not output anything
ls /etc/postgresql
ls /var/lib/postgresql
echo "<ls"
EOF

my $result;
$result = exec_as 'root', "echo '$cmd' | unshare -m sh", $outref;

is $result, 0, 'script failed';
like $$outref, qr/No space left on device/i,
    'pg_createcluster fails due to insufficient disk space';
like $$outref, qr/\nls><ls\n/, 'does not leave files behind';

check_clean;

# check disk full conditions on startup
my $cmd = <<EOF;
set -e
mount --make-rprivate / 2> /dev/null || :
export LC_MESSAGES=C
dirs="/etc/postgresql /var/lib/postgresql /var/log/postgresql"
mkdir -p \$dirs
trap "umount \$dirs" 0 HUP INT QUIT ILL ABRT PIPE TERM
mount -t tmpfs -o size=1000000 none /etc/postgresql
mount -t tmpfs -o size=50000000 none /var/lib/postgresql
mount -t tmpfs -o size=1000000 none /var/log/postgresql
pg_createcluster $MAJORS[-1] test

# fill up /var/lib/postgresql
! cat < /dev/zero > /var/lib/postgresql/cruft 2>/dev/null
echo '-- full lib --'
! pg_ctlcluster $MAJORS[-1] test start
echo '-- end full lib --'
echo '-- full lib log --'
cat /var/log/postgresql/postgresql-$MAJORS[-1]-test.log
echo '-- end full lib log --'
rm /var/lib/postgresql/cruft
pg_dropcluster $MAJORS[-1] test --stop
EOF

$result = exec_as 'root', "echo '$cmd' | unshare -m sh", $outref;
is $result, 0, 'script failed';
like $$outref, qr/^-- full lib --.*No space left on device.*^-- end full lib --/ims,
    'pg_ctlcluster prints error message';
like $$outref, qr/^-- full lib log --.*No space left on device.*^-- end full lib log --/ims,
    'log file has error message';

check_clean;

# vim: filetype=perl
