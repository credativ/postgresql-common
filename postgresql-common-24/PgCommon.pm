# Common functions for the postgresql-common framework
# (C) 2005 Martin Pitt <mpitt@debian.org>

package PgCommon;
use strict;
use Socket;

use Exporter;
our $VERSION = 1.00;
our @ISA = ('Exporter');
our @EXPORT = qw/error user_cluster_map get_cluster_port set_cluster_port
    get_cluster_socketdir set_cluster_socketdir cluster_port_running
    get_program_path cluster_info get_versions get_newest_version
    get_version_clusters next_free_port cluster_exists install_file
    change_ugid config_bool get_db_encoding get_cluster_locales
    get_cluster_databases/;
our @EXPORT_OK = qw/$confroot get_conf_value set_conf_value disable_conf_value
    replace_conf_value cluster_data_directory get_file_device/;

# configuration
my $mapfile = "/etc/postgresql-common/user_clusters";
our $confroot = "/etc/postgresql";
my $common_confdir = "/etc/postgresql-common";
my $binroot = "/usr/lib/postgresql";
my $defaultport = 5432;

# Print an error message to stderr and exit with status 1
sub error {
    print STDERR 'Error: ', $_[0], "\n";
    exit 1;
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

# Return parameter from a PostgreSQL configuration file, or undef if the parameter
# does not exist.
# Arguments: <version> <cluster> <config file name> <parameter name>
sub get_conf_value {
    return 0 unless $_[0] && $_[1];
    my $fname = "$confroot/$_[0]/$_[1]/$_[2]";
    -e $fname or $fname = "$common_confdir/$_[2]";

    if (open F, $fname) {
        while (<F>) {
            return $1 if /^\s*$_[3]\s*=\s*(\w+)\b/; # simple value
            return $1 if /^\s*$_[3]\s*=\s*'([^']*)'/; # string value
        }
        close F;
    }
    return undef;
}

# Set parameter of a PostgreSQL configuration file.
# Arguments: <version> <cluster> <config file name> <parameter name> <value>
sub set_conf_value {
    my $fname = "$confroot/$_[0]/$_[1]/$_[2]";
    my $value;
    my @lines;

    if ($_[4] =~ /^\w+$/) {
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
	if ($lines[$i] =~ /^\s*#?\s*$_[3]\s*=/) {
	    $lines[$i] = "$_[3] = $value\n";
	    $found = 1;
	    last;
	}
    }
    push (@lines, "$_[3] = $value\n") unless $found;

    # write configuration file lines
    open (F, '>'.$fname) or die "Error: could not open $fname for writing";
    foreach (@lines) {
	print F $_;
    }
    close F;
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
        open (F, '>'.$fname) or die "Error: could not open $fname for writing";
        foreach (@lines) {
            print F $_;
        }
        close F;
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

    push (@lines, "$newparam = $val\n") unless $found;

    # write configuration file lines
    open (F, '>'.$fname) or die "Error: could not open $fname for writing";
    foreach (@lines) {
        print F $_;
    }
    close F;
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
# Arguments: <version> <cluster name>
sub cluster_data_directory {
    return readlink ("$confroot/$_[0]/$_[1]/pgdata");
}

# Return the socket directory of a particular cluster or undef if the cluster
# does not exist.
# Arguments: <version> <cluster>
sub get_cluster_socketdir {
    my $socketdir = '/var/run/postgresql';
    return $socketdir unless $_[0] && $_[1];

    my $datadir = cluster_data_directory $_[0], $_[1];

    unless ($datadir && -d $socketdir and (stat $socketdir)[4] == (stat $datadir)[4]) {
        $socketdir = '/tmp';
    }
    return get_conf_value($_[0], $_[1], 'postgresql.conf',
        'unix_socket_directory') || $socketdir;
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

# Return a hash with information about a specific cluster.
# Arguments: <version> <cluster name>
# Returns: information hash (keys: pgdata, port, running, logfile, configdir,
# owneruid, ownergid, socketdir)
sub cluster_info {
    my %result;
    $result{'configdir'} = "$confroot/$_[0]/$_[1]";
    $result{'pgdata'} = cluster_data_directory $_[0], $_[1];
    $result{'logfile'} = readlink ($result{'configdir'} . "/log");
    $result{'port'} = (get_conf_value $_[0], $_[1], 'postgresql.conf', 'port') || $defaultport;
    $result{'socketdir'} = get_cluster_socketdir  $_[0], $_[1];
    $result{'running'} = cluster_port_running ($_[0], $_[1], $result{'port'});
    if ($result{'pgdata'}) {
        ($result{'owneruid'}, $result{'ownergid'}) = 
            (stat $result{'pgdata'})[4,5];
    }

    # autovacuum settings

    if ($_[0] < 8.1) {
        $result{'avac_logfile'} = readlink ($result{'configdir'} . "/autovacuum_log");
        if (get_program_path 'pg_autovacuum', $_[0]) {
            $result{'avac_enable'} = config_bool (get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'start'));
            $result{'avac_debug'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_debug');
            $result{'avac_sleep_base'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_sleep_base');
            $result{'avac_sleep_scale'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_sleep_scale');
            $result{'avac_vac_base'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_vac_base');
            $result{'avac_vac_scale'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_vac_scale');
            $result{'avac_anal_base'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_anal_base');
            $result{'avac_anal_scale'} = get_conf_value ($_[0], $_[1], 'autovacuum.conf', 'avac_anal_scale');
        } else {
            $result{'avac_enable'} = 0;
        }
    } else {
        $result{'avac_enable'} = config_bool (get_conf_value ($_[0], $_[1], 'postgresql.conf', 'autovacuum'));
    }
    
    return %result;
}

# Return an array of all available PostgreSQL versions
sub get_versions {
    my @versions = ();
    if (opendir (D, $binroot)) {
	my $entry;
        while (defined ($entry = readdir D)) {
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

# Return an array of all available clusters of given version
# Arguments: <version>
sub get_version_clusters {
    my $vdir = $confroot.'/'.$_[0].'/';
    my @clusters = ();
    if (opendir (D, $vdir)) {
	my $entry;
        while (defined ($entry = readdir D)) {
            if (-l $vdir.$entry.'/pgdata' && -r $vdir.$entry.'/postgresql.conf') {
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
	last unless grep { $_ == $port } @ports;
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
    if (! open MAP, $mapfile) {
        print "Warning: could not open $mapfile, connecting to default port\n";
        return (undef,undef,$user);
    }
    while (<MAP>) {
        s/(.*?)#.*/$1/;
        next if /^\s*$/;
        my ($u,$g,$v,$c,$db) = split;
        if (!$db) {
            print  "Warning: ignoring invalid line $. in $mapfile\n";
            next;
        }
        if (($u eq "*" || $u eq $user) && ($g eq "*" || $g eq $group)) {
	    close MAP;
            return ($v,$c, ($db eq "*") ? undef : $db);
        }
    }
    close MAP;

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

# Change effective and real user and group id. If the user id is member of the
# "shadow" group, then "shadow" will be in the set of effective groups. Exits
# with an error message if user/group ID cannot be changed.
# Arguments: <user id> <group id>
sub change_ugid {
    my ($uid, $gid) = @_;
    my $groups = $gid;
    $groups .= " $groups"; # first additional group

    # check whether owner is in the shadow group, and keep shadow privileges in
    # this case; this is a poor workaround for the lack of initgroups().
    my @shadowmembers = split /\s+/, ((getgrnam 'shadow')[3]);
    for my $m (@shadowmembers) {
	my $mid = getpwnam $m;
	if ($mid == $uid) {
	    $groups .= ' ' . (getgrnam 'shadow');
	    last;
	}
    }

    $( = $) = $groups;
    $< = $> = $uid;
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
    my $orig_euid = $>;
    $> = (stat (cluster_data_directory $version, $cluster))[4];
    my $out = `LANG=C $psql -h '$socketdir' -p $port -Atc 'select getdatabaseencoding()' $db 2>/dev/null`;
    $> = $orig_euid;
    chomp $out;
    return $out unless $?;
    return undef;
}

# Return the CTYPE and COLLATE locales of a cluster. This needs to be called
# as root or as the cluster owner.
# Arguments: <version> <cluster> 
# Returns: (LC_CTYPE, LC_COLLATE) or (undef,undef) if it cannot be determined.
sub get_cluster_locales {
    my ($version, $cluster) = @_;
    my ($lc_ctype, $lc_collate) = (undef, undef);

    my $pg_controldata = get_program_path 'pg_controldata', $version;
    open (CTRL, '-|', $pg_controldata, (cluster_data_directory $version, $cluster)) or 
	return (undef, undef);
    while (<CTRL>) {
	if (/^LC_CTYPE.*:\s*(\S+)\s*$/) {
	    $lc_ctype = $1;
	} elsif (/^LC_COLLATE.*:\s*(\S+)\s*$/) {
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
    my $orig_euid = $>;
    $> = (stat (cluster_data_directory $version, $cluster))[4];
    my $out = `LANG=C $psql -h '$socketdir' -p $port -Atl 2>/dev/null`;
    $> = $orig_euid;
    return undef if $?;
    my @dbs;
    my $i = 0;
    foreach (split "\n", $out) {
        chomp;
        $dbs[$i++] = (split '\|')[0];
    }
    return @dbs;
}

# Return the device name a file is stored at.
# Arguments: <file path>
# Returns:  device name, or '' if it cannot be determined.
sub get_file_device {
    my $dev = '';
    if (open DF, '-|', '/bin/df', $_[0]) {
        while (<DF>) {
            if (/^\/dev/) {
                $dev = (split)[0];
            }
        }
    }
    close DF;
    return $dev;
}
