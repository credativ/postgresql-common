# A debhelper build system class for building PostgreSQL extension modules using PGXS
#
# Per PostgreSQL major version, a `build-$version` subdirectory is created.
#
# Copyright: © 2020 Christoph Berg
# License: GPL-2+

package Debian::Debhelper::Buildsystem::pgxs;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem);
use Cwd;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::pgxs;

sub DESCRIPTION {
    "PGXS (PostgreSQL extensions), building in subdirectory per PostgreSQL version"
}

sub check_auto_buildable {
    my $this=shift;
    unless (-e $this->get_sourcepath("debian/pgversions")) {
        error("debian/pgversions is required to build with PGXS");
    }
    return (-e $this->get_sourcepath("Makefile")) ? 1 : 0;
}

sub new {
    my $class=shift;
    my $this=$class->SUPER::new(@_);
    $this->enforce_in_source_building();
    return $this;
}

sub build {
    my $this=shift;
    $this->doit_in_sourcedir(qw(pg_buildext build build-%v));
}

sub install {
    my $this=shift;
    my $pattern = package_pattern();
    $this->doit_in_sourcedir(qw(pg_buildext install build-%v), $pattern);
}

sub test {
    my $this=shift;
    verbose_print("Postponing tests to install stage");
}

sub clean {
    my $this=shift;
    my $pattern = package_pattern();
    $this->doit_in_sourcedir(qw(pg_buildext clean build-%v), $pattern);
}

1;
