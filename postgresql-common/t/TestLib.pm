# Common functionality for postgresql-common selftests
# (c) 2005 Martin Pitt <mpitt@debian.org>

package TestLib;
use strict;
use Exporter;
our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/ps/;

# Return the user, group, and command line of running processes for the given
# program.
sub ps {
    return `ps h -o user,group,args -C $_[0] | grep '$_[0]' | sort -u`;
}
