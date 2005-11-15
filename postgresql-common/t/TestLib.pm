# Common functionality for postgresql-common selftests
# (c) 2005 Martin Pitt <mpitt@debian.org>

package TestLib;
use strict;
use Exporter;
use Test::More;

our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/ps ok_dir exec_as deb_installed @MAJORS $LATEST_MAJOR/;

our @MAJORS = ('7.4', '8.0', '8.1');
our $LATEST_MAJOR = $MAJORS[-1];

# Return whether a given deb is installed.
# Arguments: <deb name>
sub deb_installed {
    open (DPKG, "dpkg -s $_[0] 2>/dev/null|") or die "call dpkg: $!";
    while (<DPKG>) {
	return 1 if /^Version:/;
    }

    return 0;
}

# Return the user, group, and command line of running processes for the given
# program.
sub ps {
    return `ps h -o user,group,args -C $_[0] | grep '$_[0]' | sort -u`;
}

# Return an reference to an array of all entries but . and .. of the given directory.
sub dircontent {
    opendir D, $_[0] or die "opendir: $!";
    my @e = grep { $_ ne '.' && $_ ne '..' } readdir (D);
    closedir D;
    return \@e;
}

# Check the contents of a directory.
# Arguments: <directory name> <ref to expected dir content> <test description>
sub ok_dir {
    my $content = dircontent $_[0];
    if (eq_set $content, $_[1]) {
	pass $_[2];
    } else {
	diag "Expected directory contents: [@{$_[1]}], actual contents: [@$content]\n";
	fail $_[2];
    }
}

# Execute a command as a different user and return the output. Prints the
# output of the command if exit code differs from expected one.
# Arguments: <user> <system command> <ref to output> <expected exit code>
# Returns: Program exit code
sub exec_as {
    my $uid;
    if ($_[0] =~ /\d+/) {
	$uid = int($_[0]);
    } else {
	$uid = getpwnam $_[0] or die "TestLib::exec_as: target user '$_[0]' does not exist";
    }
    $< = $uid;
    $> = $uid;
    die "changing euid: $!" if $> != $uid;
    my $out = `$_[1] 2>&1`;
    my $result = $? >> 8;
    $> = 0;
    $< = 0;
    die "changing euid back to root: $!" if $> != 0;
    $_[2] = \$out;

    if (defined $_[3] && $_[3] != $result) {
        print "command '$_[1]' did not exit with expected code $_[3]:\n";
        print $out;
    }
    return $result;
}

