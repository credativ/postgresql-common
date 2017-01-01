# Common functionality for postgresql-common selftests
#
# (C) 2005-2009 Martin Pitt <mpitt@debian.org>
# (C) 2013 Christoph Berg <myon@debian.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

package TestLib;
use strict;
use Exporter;
use Test::More;
use PgCommon qw/get_versions change_ugid/;

our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/ps ok_dir exec_as deb_installed rpm_installed package_version
    version_ge program_ok is_program_out like_program_out unlike_program_out pidof pid_env check_clean
    @ALL_MAJORS @MAJORS $delay/;

our @ALL_MAJORS = sort (get_versions()); # not affected by PG_VERSIONS/-v
our @MAJORS = $ENV{PG_VERSIONS} ? split (/\s+/, $ENV{PG_VERSIONS}) : @ALL_MAJORS;
our $delay = 500_000; # 500ms

# called if a test fails; spawn a shell if the environment variable
# FAILURE=shell is set
sub fail_debug { 
    if ($ENV{'FAILURE'} eq 'shell') {
	if ((system 'bash') != 0) {
	    exit 1;
	}
    }
}

# Return whether a given deb is installed.
# Arguments: <deb name>
sub deb_installed {
    open (DPKG, "dpkg -s $_[0] 2>/dev/null|") or die "call dpkg: $!";
    my $result = 0;
    while (<DPKG>) {
	if (/^Version:/) {
	    $result = 1;
	    last;
	}
    }
    close DPKG;

    return $result;
}

# Return whether a given rpm is installed.
# Arguments: <rpm name>
sub rpm_installed {
    open (RPM, "rpm -qa $_[0] 2>/dev/null|") or die "call rpm: $!";
    my $out = <RPM>; # returns void or the package name
    close RPM;
    return ($out =~ /./);
}

# Return a package version
# Arguments: <package>
sub package_version {
    my $package = shift;
    if ($PgCommon::rpm) {
        return `rpm --queryformat '%{VERSION}' -q $package`;
    } else {
        my $version = `dpkg-query -f '\${Version}' --show $package`;
        chomp $version;
        return $version;
    }
}

# Return whether a version is greater or equal to another one
# Arguments: <ver1> <ver2>
sub version_ge {
    my ($v1, $v2) = @_;
    use IPC::Open2;
    open2(\*CHLD_OUT, \*CHLD_IN, 'sort', '-Vr');
    print CHLD_IN "$v1\n";
    print CHLD_IN "$v2\n";
    close CHLD_IN;
    my $v_ge = <CHLD_OUT>;
    chomp $v_ge;
    return $v_ge eq $v1;
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
        if ((index $_, $_[0]) >= 0 && (index $_, '/') >= 0) {
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
	$uid = getpwnam $_[0];
        defined($uid) or die "TestLib::exec_as: target user '$_[0]' does not exist";
    }
    change_ugid ($uid, (getpwuid $uid)[3]);
    die "changing euid: $!" if $> != $uid;
    my $out = `$_[1] 2>&1`;
    my $result = $? >> 8;
    $< = $> = 0;
    $( = $) = 0;
    die "changing euid back to root: $!" if $> != 0;
    $_[2] = \$out;

    if (defined $_[3] && $_[3] != $result) {
        print "command '$_[1]' did not exit with expected code $_[3]:\n";
        print $out;
        fail_debug;
    }
    return $result;
}

# Execute a command as a particular user, and check the exit code
# Arguments: <user> <command> [<expected exit code>] [<description>]
sub program_ok {
    my ($user, $cmd, $exit, $description) = @_;
    $exit ||= 0;
    $description ||= $cmd;
    my $outref;
    ok ((exec_as $user, $cmd, \$outref, $exit) == $exit, $description);
}

# Execute a command as a particular user, and check the exit code and output
# (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output> [<description>]
sub is_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1] or fail_debug;
    is ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]")) or fail_debug;
}

# Execute a command as a particular user, and check the exit code and output
# against a regular expression (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output re> [<description>]
sub like_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1] or fail_debug;
    like ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]")) or fail_debug;
}

# Execute a command as a particular user, check the exit code, and check that
# the output does not match a regular expression (merged stdout/stderr).
# Arguments: <user> <command> <expected exit code> <expected output re> [<description>]
sub unlike_program_out {
    my $outref;
    my $result = exec_as $_[0], $_[1], $outref;
    is $result, $_[2], $_[1] or fail_debug;
    unlike ($$outref, $_[3], (defined $_[4] ? $_[4] : "correct output of $_[1]")) or fail_debug;
}

# Check that all PostgreSQL related directories are empty and no
# postmaster processes are running. Should be called at the end
# of all tests. Does 10 tests.
sub check_clean {
    is (`pg_lsclusters -h`, '', 'No existing clusters');
    is ((ps 'postmaster'), '', 'No postmaster processes left behind');
    is ((ps 'postgres'), '', 'No postgres processes left behind');
    pass ''; # this was pg_autovacuum in the past, which is obsolete

    my @check_dirs = ('/etc/postgresql', '/var/lib/postgresql',
        '/var/run/postgresql');
    foreach (@check_dirs) {
        if (-d) {
            ok_dir $_, [], "No files in $_ left behind";
        } else {
            pass "Directory $_ does not exist";
        }
    }
    # we always want /var/log/postgresql/ to exist, so that logrotate does not
    # complain about missing directories
    ok_dir '/var/log/postgresql', [], "No files in /var/log/postgresql left behind";

    is_program_out 0, 'netstat -avptn | grep ":543[2-9]\\b"', 1, '',
	'PostgreSQL TCP ports are closed';
}

1;
