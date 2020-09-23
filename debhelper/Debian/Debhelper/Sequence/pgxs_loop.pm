#!/usr/bin/perl

use warnings;
use strict;
use Debian::Debhelper::Dh_Lib;

# check if debian/control needs updating from debian/control.in
insert_after("dh_clean", "pg_buildext");
add_command_options("pg_buildext",  "checkcontrol");

# use PGXS for clean, build, and install
add_command_options("dh_auto_clean", "--buildsystem=pgxs_loop");
add_command_options("dh_auto_build", "--buildsystem=pgxs_loop");
add_command_options("dh_auto_install", "--buildsystem=pgxs_loop");

# move tests from dh_auto_test to dh_pgxs_test
remove_command("dh_auto_test");
insert_after("dh_auto_install", "dh_pgxs_test");
add_command_options("dh_pgxs_test", "loop");

1;
