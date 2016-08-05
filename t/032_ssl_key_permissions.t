use strict;
use warnings;

use lib 't';
use TestLib;
use Test::More tests => 3 + 21 * (@MAJORS);
use PgCommon;

my ($pg_uid, $pg_gid) = (getpwnam 'postgres')[2,3];
my $ssl_cert_gid = (getgrnam 'ssl-cert')[2]; # reset permissions
die "Could not determine ssl-cert gid" unless ($ssl_cert_gid);

my $snakekey = '/etc/ssl/private/ssl-cert-snakeoil.key';
is ((stat $snakekey)[4], 0, "$snakekey is owned by root");
is ((stat $snakekey)[5], $ssl_cert_gid, "$snakekey group is ssl-cert");
is ((stat $snakekey)[2], 0100640, "$snakekey mode is 0640");

foreach my $version (@MAJORS) {
    note "$version";
SKIP: {
    skip "Skip SSL key check on <= 9.0", 21 if ($version <= 9.0);
    program_ok (0, "pg_createcluster $version main");

    my $nobody_uid = (getpwnam 'nobody')[2];
    chown $nobody_uid, 0, $snakekey;
    like_program_out 'postgres', "pg_ctlcluster $version main start", 1,
        qr/private key file.*must be owned by the database user or root/,
        'ssl key owned by nobody refused';

    chown 0, 0, $snakekey;
    chmod 0644, $snakekey;
    like_program_out 'postgres', "pg_ctlcluster $version main start", 1,
        qr/private key file.*has group or world access/,
        'ssl key with permissions root:root 0644 refused';

    chown $pg_uid, $pg_gid, $snakekey;
    chmod 0640, $snakekey;
    like_program_out 'postgres', "pg_ctlcluster $version main start", 1,
        qr/private key file.*has group or world access/,
        'ssl key with permissions postgres:postgres 0640 refused';

    chown 0, $ssl_cert_gid, $snakekey;

    program_ok (0, "pg_dropcluster $version main --stop");
    is ((stat $snakekey)[4], 0, "$snakekey is owned by root");
    is ((stat $snakekey)[5], $ssl_cert_gid, "$snakekey group is ssl-cert");
    is ((stat $snakekey)[2], 0100640, "$snakekey mode is 0640");
    check_clean;
}
}
