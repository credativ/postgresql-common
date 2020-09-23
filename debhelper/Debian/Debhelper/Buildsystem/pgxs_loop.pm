# A debhelper build system class for building PostgreSQL extension modules using PGXS
#
# For packages not supporting building in subdirectories, the pgxs_loop variant builds
# for each PostgreSQL major version in turn in the top-level directory.
#
# Copyright: © 2020 Christoph Berg
# License: GPL-2+

package Debian::Debhelper::Buildsystem::pgxs_loop;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem::pgxs);
use Cwd;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::pgxs;

sub DESCRIPTION {
    "PGXS (PostgreSQL extensions), building for each PostgreSQL version in top level directory"
}

sub build {
    my $this=shift;
    verbose_print("Postponing build to install stage; if this package supports out-of-tree builds, replace --buildsystem=pgxs_loop by --buildsystem=pgxs to build in the build stage");
}

sub install {
    my $this=shift;
    my $pattern = package_pattern();
    $this->doit_in_sourcedir(qw(pg_buildext loop), $pattern);
}

1;
