#!/usr/bin/perl

use warnings;
use strict;
use Debian::Debhelper::Dh_Lib;

# check if debian/control needs updating from debian/control.in
insert_after("dh_clean", "pg_buildext");
add_command_options("pg_buildext",  "checkcontrol");

# use PGXS for clean, build, and install
add_command_options("dh_auto_clean", "--buildsystem=pgxs");
add_command_options("dh_auto_build", "--buildsystem=pgxs");
add_command_options("dh_auto_install", "--buildsystem=pgxs");

# move tests from dh_auto_test to dh_pgxs_test
remove_command("dh_auto_test");
if (! get_buildoption("nocheck") and hostarch() ne "hurd-i386") {
    insert_after("dh_link", "dh_pgxs_test");
}

1;
