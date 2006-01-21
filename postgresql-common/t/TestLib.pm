# Common functionality for postgresql-common selftests
# (c) 2005 Martin Pitt <mpitt@debian.org>

package TestLib;
use strict;
use Exporter;
use Test::More;

our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/ps ok_dir exec_as deb_installed is_program_out
    like_program_out unlike_program_out pidof pid_env @MAJORS/;

use lib '/usr/share/postgresql-common';
use PgCommon qw/get_versions/;
our @MAJORS = get_versions;

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

# Return array of pids that match the given command line
sub pidof {
    open F, '-|', 'ps', 'h', '-C', $_[0], '-o', 'pid,cmd' or die "open: $!";
    my @pids;
    while (<F>) {
        if ((index $_, $_[0]) >= 0) {
            push @pids, (split)[0];
        }
    }
    close F;
    return @pids;
}

# Return an reference to an array of all entries but . and .. of the given directory.
sub dircontent {
    opendir D, $_[0] or die "opendir: $!";
    my @e = grep { $_ ne '.' && $_ ne '..' } readdir (D);
    closedir D;
    return \@e;
}

# Return environment of given PID
sub pid_env {
    my $path = "/proc/$_[0]/environ";
    my @lines;
    open E, $path or die "open $path: $!";
    {
        local $/;
        @lines = split '\0', <E>;
    }
    close E;
    my %env;
    foreach (@lines) {
        my ($k, $v) = (split '=');
        $env{$k} = $v;
    }
    return %env;
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
# Arguments: <user> <system command> <ref to output> [<expected exit code>]
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

# Execute a command as a particular user, and check the exit code and output
# (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output> [<description>]
sub is_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1];
    is ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]"));
}

# Execute a command as a particular user, and check the exit code and output
# against a regular expression (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output re> [<description>]
sub like_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1];
    like ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]"));
}

# Execute a command as a particular user, check the exit code, and check that
# the output does not match a regular expression (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output re> [<description>]
sub unlike_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1];
    unlike ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]"));
}
