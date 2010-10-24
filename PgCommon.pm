# Common functions for the postgresql-common framework
#
# (C) 2008-2009 Martin Pitt <mpitt@debian.org>
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

package PgCommon;
use strict;
use Socket;
use POSIX;

use Exporter;
our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/error user_cluster_map get_cluster_port set_cluster_port
    get_cluster_socketdir set_cluster_socketdir cluster_port_running
    get_cluster_start_conf set_cluster_start_conf set_cluster_pg_ctl_conf
    get_program_path cluster_info get_versions get_newest_version version_exists
    get_version_clusters next_free_port cluster_exists install_file
    change_ugid config_bool get_db_encoding get_db_locales get_cluster_locales
    get_cluster_databases read_cluster_conf_file read_pg_hba/;
our @EXPORT_OK = qw/$confroot read_conf_file get_conf_value set_conf_value
    disable_conf_value replace_conf_value cluster_data_directory
    get_file_device/;

# configuration
my $mapfile = "/etc/postgresql-common/user_clusters";
our $confroot = $ENV{'PG_CLUSTER_CONF_ROOT'} || "/etc/postgresql";
my $common_confdir = "/etc/postgresql-common";
my $binroot = "/usr/lib/postgresql";
my $defaultport = 5432;

# Print an error message to stderr and exit with status 1
sub error {
    print STDERR 'Error: ', $_[0], "\n";
    exit 1;
}

{
    my %saved_env;

    # untaint the environment for executing an external program
    # Optional arguments: list of additional variables
    sub prepare_exec {
	my @cleanvars = qw/PATH IFS ENV BASH_ENV CDPATH/;
	push @cleanvars, @_;
	%saved_env = ();

	foreach (@cleanvars) {
	    $saved_env{$_} = $ENV{$_};
	    delete $ENV{$_};
	}

	$ENV{'PATH'} = '';
    }

    # restore the environment after prepare_exec()
    sub restore_exec {
	foreach (keys %saved_env) {
	    if (defined $saved_env{$_}) {
		$ENV{$_} = $saved_env{$_};
	    } else {
		delete $ENV{$_};
	    }
	}
    }
}

# Returns '1' if the argument is a configuration file value that stands for
# true (ON, TRUE, YES, or 1, case insensitive), '0' if the argument represents
# a false value (OFF, FALSE, NO, or 0, case insensitive), or undef otherwise.
sub config_bool {
    return undef unless defined($_[0]);
    return 1 if ($_[0] =~ /^(on|true|yes|1)$/i);
    return 0 if ($_[0] =~ /^(off|false|no|0)$/i);
    return undef;
}

# Read a 'var = value' style configuration file and return a hash with the
# values. Error out if the file cannot be read.
# Arguments: <path>
# Returns: hash (empty if file does not exist)
sub read_conf_file {
    my %conf;
    local (*F);

    return %conf unless -e $_[0];

    if (open F, $_[0]) {
        while (<F>) {
            if (/^\s*(?:#.*)?$/) {
                next;
	    } elsif (/^\s*include\s+'([^']+)'\s*$/) {
		my ($k, $v, $path, %include_conf);
		$path = $1;
		unless (substr($path, 0, 1) eq '/') {
		    my @p = split '/', $_[0];
		    my $dirname = join '/', @p[0..($#p-1)];
		    $path = "$dirname/$path";
		}

		# read included file and merge into %conf
		%include_conf = read_conf_file($path);
		while ( ($k, $v) = each(%include_conf) ) {
		    $conf{$k} = $v;
		}

            } elsif (/^\s*([a-zA-Z0-9_.-]+)\s*=\s*'((?:[^']|(?:(?<=\\)'))*)'\s*(?:#.*)?$/) {
                # string value
                my $k = $1;
                my $v = $2;
                $v =~ s/\\(.)/$1/g;
                $conf{$k} = $v;
            } elsif (/^\s*([a-zA-Z0-9_.-]+)\s*=\s*(-?[\w.]+)\s*(?:#.*)?$/) {
                # simple value
                $conf{$1} = $2;
            } else {
                error "Invalid line $. in $_[0]: »$_«";
            }
        }
        close F;
    } else {
        error "could not read $_[0]: $!";
    }

    return %conf;
}

# Read a 'var = value' style configuration file from a cluster configuration
# directory (with /etc/postgresql-common/<file name> as fallback) and return a
# hash with the values. Error out if the file cannot be read.
# Arguments: <version> <cluster> <config file name>
# Returns: hash (empty if the file does not exist)
sub read_cluster_conf_file {
     my $fname = "$confroot/$_[0]/$_[1]/$_[2]";
     -e $fname or $fname = "$common_confdir/$_[2]";
    return read_conf_file $fname;
}

# Return parameter from a PostgreSQL configuration file, or undef if the parameter
# does not exist.
# Arguments: <version> <cluster> <config file name> <parameter name>
sub get_conf_value {
    my %conf = (read_cluster_conf_file $_[0], $_[1], $_[2]);
    return $conf{$_[3]};
}

# Set parameter of a PostgreSQL configuration file.
# Arguments: <version> <cluster> <config file name> <parameter name> <value>
sub set_conf_value {
    my $fname = "$confroot/$_[0]/$_[1]/$_[2]";
    my $value;
    my @lines;

    if ($_[4] =~ /^-?[\w.]+$/) {
	$value = $_[4];
    } else {
	$value = "'$_[4]'";
    }

    # read configuration file lines
    open (F, $fname) or die "Error: could not open $fname for reading";
    push @lines, $_ while (<F>);
    close F;

    my $found = 0;
    for (my $i=0; $i <= $#lines; ++$i) {
	if ($lines[$i] =~ /^\s*#?\s*$_[3]\s*=\s*\w+\b((?:\s*#.*)?)/ or
	    $lines[$i] =~ /^\s*#?\s*$_[3]\s*=\s*'[^']*'((?:\s*#.*)?)/) {
	    $lines[$i] = "$_[3] = $value$1\n";
	    $found = 1;
	    last;
	}
    }
    push (@lines, "$_[3] = $value\n") unless $found;

    # write configuration file lines
    open (F, ">$fname.new") or die "Error: could not open $fname.new for writing";
    foreach (@lines) {
	print F $_ or die "writing $fname.new: $!";
    }
    close F;

    # copy permissions
    my @st = stat $fname or die "stat: $!";
    chown $st[4], $st[5], "$fname.new"; # might fail as non-root
    chmod $st[2], "$fname.new" or die "chmod: $1";

    rename "$fname.new", "$fname";
}

# Disable a parameter in a PostgreSQL configuration file by prepending it with
# a '#'. Appends an optional explanatory comment <reason> if given.
# Arguments: <version> <cluster> <config file name> <parameter name> <reason>
sub disable_conf_value {
    my $fname = "$confroot/$_[0]/$_[1]/$_[2]";
    my $value;
    my @lines;

    # read configuration file lines
    open (F, $fname) or die "Error: could not open $fname for reading";
    push @lines, $_ while (<F>);
    close F;

    my $changed = 0;
    for (my $i=0; $i <= $#lines; ++$i) {
	if ($lines[$i] =~ /^\s*$_[3]\s*=/) {
	    $lines[$i] = '#'.$lines[$i];
	    chomp $lines[$i];
            $lines[$i] .= ' #'.$_[4]."\n" if $_[4];
            $changed = 1;
	    last;
	}
    }

    # write configuration file lines
    if ($changed) {
        open (F, ">$fname.new") or die "Error: could not open $fname.new for writing";
        foreach (@lines) {
	    print F $_ or die "writing $fname.new: $!";
        }
        close F;

	# copy permissions
	my @st = stat $fname or die "stat: $!";
	chown $st[4], $st[5], "$fname.new"; # might fail as non-root
	chmod $st[2], "$fname.new" or die "chmod: $1";

	rename "$fname.new", "$fname";
    }
}

# Replace a parameter in a PostgreSQL configuration file. The old parameter is
# prepended with a '#' and  gets an optional explanatory comment <reason>
# appended, if given. The new parameter is inserted directly after the old one.
# Arguments: <version> <cluster> <config file name> <old parameter name>
#            <reason> <new parameter name> <new value>
sub replace_conf_value {
    my ($version, $cluster, $configfile, $oldparam, $reason, $newparam, $val) = @_;
    my $fname = "$confroot/$version/$cluster/$configfile";
    my @lines;

    # quote $val if necessary
    unless ($val =~ /^\w+$/) {
	$val = "'$val'";
    }

    # read configuration file lines
    open (F, $fname) or die "Error: could not open $fname for reading";
    push @lines, $_ while (<F>);
    close F;

    my $found = 0;
    for (my $i = 0; $i <= $#lines; ++$i) {
	if ($lines[$i] =~ /^\s*$oldparam\s*=/) {
	    $lines[$i] = '#'.$lines[$i];
	    chomp $lines[$i];
            $lines[$i] .= ' #'.$reason."\n" if $reason;

            # insert the new param
            splice @lines, $i+1, 0, "$newparam = $val\n";
            ++$i;

            $found = 1;
	    last;
	}
    }

    return if !$found;

    # write configuration file lines
    open (F, ">$fname.new") or die "Error: could not open $fname.new for writing";
    foreach (@lines) {
	print F $_ or die "writing $fname.new: $!";
    }
    close F;

    # copy permissions
    my @st = stat $fname or die "stat: $!";
    chown $st[4], $st[5], "$fname.new"; # might fail as non-root
    chmod $st[2], "$fname.new" or die "chmod: $1";

    rename "$fname.new", "$fname";
}

# Return the port of a particular cluster or undef if the cluster
# does not exist.
# Arguments: <version> <cluster>
sub get_cluster_port {
    return get_conf_value($_[0], $_[1], 'postgresql.conf', 'port');
}

# Set the port of a particular cluster. 
# Arguments: <version> <cluster> <port>
sub set_cluster_port {
    set_conf_value $_[0], $_[1], 'postgresql.conf', 'port', $_[2];
}

# Return cluster data directory.
# Arguments: <version> <cluster name> [<config_hash>]
sub cluster_data_directory {
    my $d;
    if ($_[2]) {
        $d = ${$_[2]}{'data_directory'};
    } else {
        $d = get_conf_value($_[0], $_[1], 'postgresql.conf', 'data_directory');
    }
    if (!$d) {
        # fall back to /pgdata symlink (supported by earlier p-common releases)
        $d = readlink "$confroot/$_[0]/$_[1]/pgdata";
    }
    ($d) = $d =~ /(.*)/ if defined $d; #untaint
    return $d;
}

# Return the socket directory of a particular cluster or undef if the cluster
# does not exist.
# Arguments: <version> <cluster>
sub get_cluster_socketdir {
    # if it is explicitly configured, just return it
    my $socketdir = get_conf_value($_[0], $_[1], 'postgresql.conf',
        'unix_socket_directory');
    return $socketdir if $socketdir;

    # try to determine whether this is a postgres owned cluster and we default
    # to /var/run/postgresql
    $socketdir = '/var/run/postgresql';
    my @socketdirstat = stat $socketdir;

    error "Cannot stat $socketdir" unless @socketdirstat;

    if ($_[0] && $_[1]) {
        my $datadir = cluster_data_directory $_[0], $_[1];
        error "Invalid data directory" unless $datadir;
        my @datadirstat = stat $datadir;
        unless (@datadirstat) {
            my @p = split '/', $datadir;
            my $parent = join '/', @p[0..($#p-1)];
            error "$datadir is not accessible; please fix the directory permissions ($parent/ should be world readable)" unless @datadirstat;
        }

        $socketdir = '/tmp' if $socketdirstat[4] != $datadirstat[4];
    }

    return $socketdir;
}

# Set the socket directory of a particular cluster. 
# Arguments: <version> <cluster> <directory>
sub set_cluster_socketdir {
    set_conf_value $_[0], $_[1], 'postgresql.conf', 'unix_socket_directory', $_[2];
}

# Return the path of a program of a particular version.
# Arguments: <program name> <version>
sub get_program_path {
    return '' unless defined($_[0]) && defined($_[1]);
    my $path = "$binroot/$_[1]/bin/$_[0]";
    ($path) = $path =~ /(.*)/; #untaint
    return $path if -x $path;
    return '';
}

# Check whether a postmaster server is running at the specified port.
# Arguments: <version> <cluster> <port>
sub cluster_port_running {
    die "port_running: invalid port $_[2]" if $_[2] !~ /\d+/;
    my $socketdir = get_cluster_socketdir $_[0], $_[1];
    my $socketpath = "$socketdir/.s.PGSQL.$_[2]";
    return 0 unless -S $socketpath;

    socket(SRV, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
    my $running = connect(SRV, sockaddr_un($socketpath));
    close SRV;
    return $running ? 1 : 0;
}

# Read, verify, and return the current start.conf setting.
# Arguments: <version> <cluster>
# Returns: auto | manual | disabled
sub get_cluster_start_conf {
    # start.conf setting
    my $start = 'auto';
    my $start_conf = "$confroot/$_[0]/$_[1]/start.conf";
    if (-e $start_conf) {
	open F, $start_conf or error "Could not open $start_conf: $!";
	while (<F>) {
	    s/#.*$//;
	    s/^\s*//;
	    s/\s*$//;
	    next unless $_;
	    $start = $_;
	    last;
	}
	close F;

	error 'Invalid mode in start.conf' unless $start eq 'auto' || 
	    $start eq 'manual' || $start eq 'disabled';
    }

    return $start;
}

# Change start.conf setting.
# Arguments: <version> <cluster> <value>
# <value> = auto | manual | disabled
sub set_cluster_start_conf {
    my ($v, $c, $val) = @_;

    error "Invalid mode: '$val'" unless $val eq 'auto' || 
	    $val eq 'manual' || $val eq 'disabled';

    my $perms = 0644;

    # start.conf setting
    my $start_conf = "$confroot/$_[0]/$_[1]/start.conf";
    my $text;
    if (-e $start_conf) {
	open F, $start_conf or error "Could not open $start_conf: $!";
	while (<F>) {
            if (/^\s*(?:auto|manual|disabled)\b(.*$)/) {
                $text .= $val . $1 . "\n";
            } else {
                $text .= $_;
            }
	}

        # preserve permissions if it already exists
        $perms = (stat F)[2];
        error "Could not get permissions of $start_conf: $!" unless $perms;
	close F;
    } else {
        $text = "# Automatic startup configuration
# auto: automatically start/stop the cluster in the init script
# manual: do not start/stop in init scripts, but allow manual startup with
#         pg_ctlcluster
# disabled: do not allow manual startup with pg_ctlcluster (this can be easily
#           circumvented and is only meant to be a small protection for
#           accidents).

$val
";
    }

    open F, '>' . $start_conf or error "Could not open $start_conf for writing: $!";
    chmod $perms, $start_conf;
    print F $text;
    close F;
}

# Change pg_ctl.conf setting.
# Arguments: <version> <cluster> <options>
# <options> = options passed to pg_ctl(1)
sub set_cluster_pg_ctl_conf {
    my ($v, $c, $opts) = @_;
    my $perms = 0644;

    # pg_ctl.conf setting
    my $pg_ctl_conf = "$confroot/$v/$c/pg_ctl.conf";
    my $text = "# Automatic pg_ctl configuration
# This configuration file contains cluster specific options to be passed to
# pg_ctl(1).

pg_ctl_options = '$opts'
";

    open F, '>' . $pg_ctl_conf or error "Could not open $pg_ctl_conf for writing: $!";
    chmod $perms, $pg_ctl_conf;
    print F $text;
    close F;
}

# Return a hash with information about a specific cluster.
# Arguments: <version> <cluster name>
# Returns: information hash (keys: pgdata, port, running, logfile [unless it
#          has a custom one], configdir, owneruid, ownergid, socketdir)
sub cluster_info {
    error 'cluster_info must be called with <version> <cluster> arguments' unless $_[0] && $_[1];

    my %result;
    $result{'configdir'} = "$confroot/$_[0]/$_[1]";
    my %postgresql_conf = read_cluster_conf_file $_[0], $_[1], 'postgresql.conf';
    $result{'pgdata'} = cluster_data_directory $_[0], $_[1], \%postgresql_conf;
    $result{'port'} = $postgresql_conf{'port'} || $defaultport;
    $result{'socketdir'} = get_cluster_socketdir  $_[0], $_[1];
    $result{'running'} = cluster_port_running ($_[0], $_[1], $result{'port'});
    if ($result{'pgdata'}) {
        ($result{'owneruid'}, $result{'ownergid'}) = 
            (stat $result{'pgdata'})[4,5];
    }
    $result{'start'} = get_cluster_start_conf $_[0], $_[1];

    # default log file (only if not expliticly configured in postgresql.conf)
    unless (exists $postgresql_conf{'log_filename'} || 
	exists $postgresql_conf{'log_directory'} ||
	(defined $postgresql_conf{'log_destination'} &&
	    $postgresql_conf{'log_destination'} eq 'syslog')) {
        my $log_symlink = $result{'configdir'} . "/log";
        if (-l $log_symlink) {
            ($result{'logfile'}) = readlink ($log_symlink) =~ /(.*)/; # untaint
        } else {
            $result{'logfile'} = "/var/log/postgresql/postgresql-$_[0]-$_[1].log";
        }
    }

    # autovacuum defaults to on since 8.3
    $result{'avac_enable'} = config_bool $postgresql_conf{'autovacuum'} || ($_[0] ge '8.3');
    
    return %result;
}

# Return an array of all available PostgreSQL versions
sub get_versions {
    my @versions = ();
    if (opendir (D, $binroot)) {
	my $entry;
        while (defined ($entry = readdir D)) {
            next if $entry eq '.' || $entry eq '..';
	    ($entry) = $entry =~ /^(\d+\.\d+)$/; # untaint
            push @versions, $entry if get_program_path ('psql', $entry);
        }
        closedir D;
    }
    return @versions;
}

# Return the newest available version
sub get_newest_version {
    my $newest = 0;
    map { $newest = $_ if $newest < $_ } get_versions;
    return $newest;
}

# Check whether a version exists
sub version_exists {
    return (grep { $_ eq $_[0] } get_versions) ? 1 : 0;
}

# Return an array of all available clusters of given version
# Arguments: <version>
sub get_version_clusters {
    my $vdir = $confroot.'/'.$_[0].'/';
    my @clusters = ();
    if (opendir (D, $vdir)) {
	my $entry;
        while (defined ($entry = readdir D)) {
            next if $entry eq '.' || $entry eq '..';
	    ($entry) = $entry =~ /^(.*)$/; # untaint
            if (-r $vdir.$entry.'/postgresql.conf') {
                push @clusters, $entry;
            }
        }
        closedir D;
    }
    return @clusters;
}

# Check if a cluster exists.
# Arguments: <version> <cluster>
sub cluster_exists {
    for my $c (get_version_clusters $_[0]) {
	return 1 if $c eq $_[1];
    }
    return 0;
}

# Return the next free PostgreSQL port.
sub next_free_port {
    # create list of already used ports
    my @ports;
    for my $v (get_versions) {
	for my $c (get_version_clusters $v) {
	    my $p = (get_conf_value $v, $c, 'postgresql.conf', 'port') || $defaultport;
	    push @ports, $p;
	}
    }

    my $port;
    for ($port = $defaultport; ; ++$port) {
	next if grep { $_ == $port } @ports;

        # check if port is already in use
        socket (SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp')) or 
            die "could not create socket: $!";
        my $res = bind (SOCK, sockaddr_in($port, INADDR_ANY));
        close SOCK;
        last if $res;
    }

    return $port;
}

# Return the PostgreSQL version, cluster, and database to connect to. version
# is always set (defaulting to the version of the default port if no matching
# entry is found, or finally to the latest installed version if there are no
# clusters at all), cluster and database may be 'undef'. If only one cluster
# exists, and no matching entry is found in the map files, that cluster is
# returned.
sub user_cluster_map {
    my ($user, $pwd, $uid, $gid) = getpwuid $>;
    my $group = (getgrgid  $gid)[0];

    # check per-user configuration file
    my $home = $ENV{"HOME"} || (getpwuid $>)[7];
    my $homemapfile = $home . '/.postgresqlrc';
    if (open MAP, $homemapfile) {
	while (<MAP>) {
	    s/(.*?)#.*/$1/;
	    next if /^\s*$/;
	    my ($v,$c,$db) = split;
	    if (!version_exists $v) {
		error "$homemapfile line $.: version $v does not exist";
	    }
	    if (!cluster_exists $v, $c and $c !~ /^(\S+):(\d*)$/) {
		error "$homemapfile line $.: cluster $v/$c does not exist";
	    }
	    if ($db) {
		close MAP;
		return ($v, $c, ($db eq "*") ? undef : $db);
	    } else {
		print  "Warning: ignoring invalid line $. in $homemapfile\n";
		next;
	    }
	}
	close MAP;
    }

    # check global map file
    if (open MAP, $mapfile) {
        while (<MAP>) {
            s/(.*?)#.*/$1/;
            next if /^\s*$/;
            my ($u,$g,$v,$c,$db) = split;
            if (!$db) {
                print  "Warning: ignoring invalid line $. in $mapfile\n";
                next;
            }
	    if (!version_exists $v) {
		error "$mapfile line $.: version $v does not exist";
	    }
	    if (!cluster_exists $v, $c and $c !~ /^(\S+):(\d*)$/) {
		error "$mapfile line $.: cluster $v/$c does not exist";
	    }
            if (($u eq "*" || $u eq $user) && ($g eq "*" || $g eq $group)) {
                close MAP;
                return ($v,$c, ($db eq "*") ? undef : $db);
            }
        }
        close MAP;
    }

    # if only one cluster exists, use that
    my $count = 0;
    my ($last_version, $last_cluster, $defaultport_version, $defaultport_cluster);
    for my $v (get_versions) {
	for my $c (get_version_clusters $v) {
	    my $port = (get_conf_value $v, $c, 'postgresql.conf', 'port') || $defaultport;
            $last_version = $v;
            $last_cluster = $c;
	    if ($port == $defaultport) {
		$defaultport_version = $v;
		$defaultport_cluster = $c;
	    }
            ++$count;
	}
    }
    return ($last_version, $last_cluster, undef) if $count == 1;

    if ($count == 0) {
	# if there are no local clusters, use latest clients for accessing
	# network clusters
	return (get_newest_version, undef, undef);
    }

    # more than one cluster exists, return cluster at default port
    return ($defaultport_version, $defaultport_cluster, undef);
}

# Copy a file to a destination and setup permissions
# Arguments: <source file> <destination file or dir> <uid> <gid> <permissions>
sub install_file {
    my ($source, $dest, $uid, $gid, $perm) = @_;
    
    if (system '/usr/bin/install', '-o', $uid, '-g', $gid, '-m', $perm, $source, $dest) {
	error "install_file: could not install $source to $dest";
    }
}

# Change effective and real user and group id. Also activates all auxiliary
# groups the user is in. Exits with an error message if user/group ID cannot be
# changed.
# Arguments: <user id> <group id>
sub change_ugid {
    my ($uid, $gid) = @_;

    # auxiliary groups
    my $uname = (getpwuid $uid)[0];
    prepare_exec;
    my $groups = "$gid " . `/usr/bin/id -G $uname`;
    restore_exec;

    $) = $groups;
    $( = $gid;
    $> = $< = $uid;
    error 'Could not change user id' if $< != $uid;
    error 'Could not change group id' if $( != $gid;
}

# Return the encoding of a particular database in a cluster. This requires
# access privileges to that database, so this function should be called as the
# cluster owner.
# Arguments: <version> <cluster> <database>
# Returns: Encoding or undef if it cannot be determined.
sub get_db_encoding {
    my ($version, $cluster, $db) = @_;
    my $port = get_cluster_port $version, $cluster;
    my $socketdir = get_cluster_socketdir $version, $cluster;
    my $psql = get_program_path 'psql', $version;
    return undef unless ($port && $socketdir && $psql);

    # try to swich to cluster owner
    prepare_exec 'LC_ALL';
    $ENV{'LC_ALL'} = 'C';
    my $orig_euid = $>;
    $> = (stat (cluster_data_directory $version, $cluster))[4];
    open PSQL, '-|', $psql, '-h', $socketdir, '-p', $port, '-Atc', 
        'select getdatabaseencoding()', $db or 
        die "Internal error: could not call $psql to determine db encoding: $!";
    my $out = <PSQL>;
    close PSQL;
    $> = $orig_euid;
    restore_exec;
    return undef if $?;
    chomp $out;
    ($out) = $out =~ /^([\w.-]+)$/; # untaint
    return $out;
}

# Return locale of a particular database in a cluster. This requires access
# privileges to that database, so this function should be called as the cluster
# owner. (For versions >= 8.4; for older versions use get_cluster_locales()).
# Arguments: <version> <cluster> <database>
# Returns: (LC_CTYPE, LC_COLLATE) or (undef,undef) if it cannot be determined.
sub get_db_locales {
    my ($version, $cluster, $db) = @_;
    my $port = get_cluster_port $version, $cluster;
    my $socketdir = get_cluster_socketdir $version, $cluster;
    my $psql = get_program_path 'psql', $version;
    return undef unless ($port && $socketdir && $psql);
    my ($ctype, $collate);

    # try to swich to cluster owner
    prepare_exec 'LC_ALL';
    $ENV{'LC_ALL'} = 'C';
    my $orig_euid = $>;
    $> = (stat (cluster_data_directory $version, $cluster))[4];
    open PSQL, '-|', $psql, '-h', $socketdir, '-p', $port, '-Atc', 
        'SHOW lc_ctype', $db or 
        die "Internal error: could not call $psql to determine db lc_ctype: $!";
    my $out = <PSQL>;
    close PSQL;
    ($ctype) = $out =~ /^([\w.-]+)$/; # untaint
    open PSQL, '-|', $psql, '-h', $socketdir, '-p', $port, '-Atc', 
        'SHOW lc_collate', $db or 
        die "Internal error: could not call $psql to determine db lc_collate: $!";
    $out = <PSQL>;
    close PSQL;
    ($collate) = $out =~ /^([\w.-]+)$/; # untaint
    $> = $orig_euid;
    restore_exec;
    chomp $ctype;
    chomp $collate;
    return ($ctype, $collate) unless $?;
    return (undef, undef);
}

# Return the CTYPE and COLLATE locales of a cluster. This needs to be called
# as root or as the cluster owner. (For versions <= 8.3; for >= 8.4, use
# get_db_locales()).
# Arguments: <version> <cluster> 
# Returns: (LC_CTYPE, LC_COLLATE) or (undef,undef) if it cannot be determined.
sub get_cluster_locales {
    my ($version, $cluster) = @_;
    my ($lc_ctype, $lc_collate) = (undef, undef);

    if ($version ge '8.4') {
	print STDERR "Error: get_cluster_locales() does not work for 8.4+\n";
	exit 1;
    }

    my $pg_controldata = get_program_path 'pg_controldata', $version;
    if (! -e $pg_controldata) {
        print STDERR "Error: pg_controldata not found, please install postgresql-$version\n";
        exit 1;
    }
    prepare_exec ('LC_ALL', 'LANG', 'LANGUAGE');
    $ENV{'LC_ALL'} = 'C';
    my $result = open (CTRL, '-|', $pg_controldata, (cluster_data_directory $version, $cluster));
    restore_exec;
    return (undef, undef) unless defined $result;
    while (<CTRL>) {
	if (/^LC_CTYPE\W*(\S+)\s*$/) {
	    $lc_ctype = $1;
	} elsif (/^LC_COLLATE\W*(\S+)\s*$/) {
	    $lc_collate = $1;
	}
    }
    close CTRL;
    return ($lc_ctype, $lc_collate);
}

# Return an array with all databases of a cluster. This requires connection
# privileges to template1, so this function should be called as the
# cluster owner.
# Arguments: <version> <cluster> 
# Returns: array of database names or undef on error.
sub get_cluster_databases {
    my ($version, $cluster) = @_;
    my $port = get_cluster_port $version, $cluster;
    my $socketdir = get_cluster_socketdir $version, $cluster;
    my $psql = get_program_path 'psql', $version;
    return undef unless ($port && $socketdir && $psql);

    # try to swich to cluster owner
    prepare_exec 'LC_ALL';
    $ENV{'LC_ALL'} = 'C';
    my $orig_euid = $>;
    $> = (stat (cluster_data_directory $version, $cluster))[4];

    my @dbs;
    my @fields;
    if (open PSQL, '-|', $psql, '-h', $socketdir, '-p', $port, '-Atl') {
        while (<PSQL>) {
            chomp;
            @fields = split '\|';
            next if $#fields < 2; # remove access privs which get line broken
            push (@dbs, $fields[0]);
        }
        close PSQL;
    }

    $> = $orig_euid;
    restore_exec;

    return $? ? undef : @dbs;
}

# Return the device name a file is stored at.
# Arguments: <file path>
# Returns:  device name, or '' if it cannot be determined.
sub get_file_device {
    my $dev = '';
    prepare_exec;
    if (open DF, '-|', '/bin/df', $_[0]) {
        while (<DF>) {
            if (/^\/dev/) {
                $dev = (split)[0];
            }
        }
    }
    restore_exec;
    close DF;
    return $dev;
}


# Parse a single pg_hba.conf line.
# Arguments: <line>
# Returns: Hash reference (only returns line and type==undef for invalid lines)
# line -> the verbatim pg_hba line
# type -> comment, local, host, hostssl, hostnossl, undef
# db -> database name
# user -> user name
# method -> trust, reject, md5, crypt, password, krb5, ident, pam
# ip -> ip address
# mask -> network mask (either a single number as number of bits, or bit mask)
my %valid_methods = qw/trust 1 reject 1 md5 1 crypt 1 password 1 krb5 1 ident 1 pam 1/;
sub parse_hba_line {
    my $l = $_[0];
    chomp $l;

    # comment line?
    return { 'type' => 'comment', 'line' => $l } if ($l =~ /^\s*($|#)/);

    my $res = { 'line' => $l };
    my @tok = split /\s+/, $l;
    goto error if $#tok < 3;

    $$res{'type'} = shift @tok;
    $$res{'db'} = shift @tok;
    $$res{'user'} = shift @tok;

    # local connection?
    if ($$res{'type'} eq 'local') {
	goto error if $#tok > 1;
	goto error unless $valid_methods{$tok[0]};
	$$res{'method'} = join (' ', @tok);
	return $res;
    } 

    # host connection?
    if ($$res{'type'} =~ /^host((no)?ssl)?$/) {
	my ($i, $c) = split '/', (shift @tok);
	goto error unless $i;
	$$res{'ip'} = $i;

	# CIDR mask given?
	if (defined $c) {
	    goto error if $c !~ /^(\d+)$/;
	    $$res{'mask'} = $c;
	} else {
	    $$res{'mask'} = shift @tok;
	}

	goto error if $#tok > 1;
	goto error unless $valid_methods{$tok[0]};
	$$res{'method'} = join (' ', @tok);
	return $res;
    }

error:
    $$res{'type'} = undef;
    return $res;
}

# Parse given pg_hba.conf file.
# Arguments: <pg_hba.conf path>
# Returns: Array with hash refs; for hash contents, see parse_hba_line().
sub read_pg_hba {
    open HBA, $_[0] or return undef;
    my @hba;
    while (<HBA>) {
	my $r = parse_hba_line $_;
	push @hba, $r;
    }
    close HBA;
    return @hba;
}

1;
