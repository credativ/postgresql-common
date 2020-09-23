# A debhelper build system class for building PostgreSQL extension modules using PGXS
#
# Copyright: © 2020 Christoph Berg
# License: GPL-2+

package Debian::Debhelper::pgxs;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(package_pattern);

=head1 package_pattern()

From C<debian/control.in>, look for the package name containing the
B<PGVERSION> placeholder, and return it in the format suitable for passing to
B<pg_buildext>, i.e. with B<PGVERSION> replaced by B<%v>.

For B<Package: postgresql-PGVERSION-unit> it will return B<postgresql-%v-unit>.

Errors out if more than one package with the B<PGVERSION> placeholder is found.

=cut

sub package_pattern () {
    open F, "debian/control.in" or die "debian/control.in: $!";
    my $pattern;
    while (<F>) {
        if (/^Package: (.*)PGVERSION(.*)/) {
            die "More than one Package with PGVERSION placeholder found in debian/control.in, cannot build with dh --buildsystem=pgxs. Use pg_buildext manually." if ($pattern);
            $pattern = "$1%v$2";
        }
    }
    close F;
    return $pattern;
}

1;
