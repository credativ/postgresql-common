# Common functions for the postgresql-common framework
# (C) 2005 Martin Pitt <mpitt@debian.org>

package PgCommon;

use Exporter;
$VERSION = 1.00;
@ISA = ('Exporter');
@EXPORT = qw/error user_cluster_map get_cluster_port set_cluster_port
    get_program_path cluster_info get_versions get_newest_version
    get_version_clusters next_free_port cluster_exists/;
@EXPORT_OK = qw/$confroot/;

# configuration
$mapfile = "/etc/postgresql-common/user_clusters";
$confroot = "/etc/postgresql";
$binroot = "/usr/lib/postgresql";
$defaultport = 5432;

# Print an error message to stderr and exit with status 1
sub error {
    print STDERR 'Error: ', $_[0], "\n";
    exit 1;
}

# Return parameter from a PostgreSQL configuration file, or undef if the parameter
# does not exist.
# Arguments: <version> <cluster> <config file name> <parameter name>
sub get_conf_value {
    return 0 unless $_[0] && $_[1];
    if (open F, "$confroot/$_[0]/$_[1]/$_[2]") {
        while (<F>) {
            return $1 if /^\s*$_[3]\s*=\s*(\w+)\b/;
        }
        close F;
    }
    return undef;
}

# Set parameter of a PostgreSQL configuration file.
# Arguments: <version> <cluster> <config file name> <parameter name> <value>
sub set_conf_value {
    my $fname = "$confroot/$_[0]/$_[1]/$_[2]";

    # read configuration file lines
    open (F, $fname) or die "Error: could not open $fname for reading";
    push @lines, $_ while (<F>);
    close F;

    my $found = 0;
    for ($i=0; $i <= $#lines; ++$i) {
	if ($lines[$i] =~ /^\s*#?\s*$_[3]\s*=/) {
	    $lines[$i] = "$_[3] = $_[4]\n";
	    $found = 1;
	}
    }
    push (@lines, "$_[3] = $_[4]\n") unless $found;

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

# Return the path of a program of a particular version.
# Arguments: <program name> <version>
sub get_program_path {
    my $path = "$binroot/$_[1]/bin/$_[0]";
    return $path if -x $path;
    return '';
}

# Check whether a postmaster server is running at the specified port.
# Arguments: <version> <port>
sub port_running {
    $psql = get_program_path "psql", $_[0];
    die "port_running: invalid port $_[1]" if $_[1] !~ /\d+/;
    $out = `LANG=C $psql -p $_[1] -l 2>&1 > /dev/null`;
    return 1 unless $?;
    return (index ($out, "could not connect") < 0);
}

# Return a hash with information about a specific cluster.
# Arguments: <version> <cluster name>
# Returns: information hash (keys: pgdata, port, running, logfile, configdir,
# owneruid, ownergid)
sub cluster_info {
    $result{'configdir'} = "$confroot/$_[0]/$_[1]";
    $result{'pgdata'} = readlink ($result{'configdir'} . "/pgdata");
    $result{'logfile'} = readlink ($result{'configdir'} . "/log");
    $result{'port'} = (get_conf_value $_[0], $_[1], 'postgresql.conf', 'port') || $defaultport;
    $result{'running'} = port_running ($_[0], $result{'port'});
    if ($result{'pgdata'}) {
        ($result{'owneruid'}, $result{'ownergid'}) = 
            (stat $result{'pgdata'})[4,5];
    }
    return %result;
}

# Return an array of all available PostgreSQL versions
sub get_versions {
    my @versions = ();
    if (opendir (D, $binroot)) {
        while (defined ($f = readdir D)) {
            push @versions, $f if get_program_path ('postmaster', $f);
        }
        closedir D;
    }
    return @versions;
}

# Return the newest available version
sub get_newest_version {
    $newest = 0;
    map { $newest = $_ if $newest < $_ } get_versions;
    return $newest;
}

# Return an array of all available clusters of given version
# Arguments: <version>
sub get_version_clusters {
    my $vdir = $confroot.'/'.$_[0].'/';
    my @clusters = ();
    if (opendir (D, $vdir)) {
        while (defined ($f = readdir D)) {
            if (-l $vdir.$f.'/pgdata' && -r $vdir.$f.'/postgresql.conf') {
                push @clusters, $f;
            }
        }
        closedir D;
    }
    return @clusters;
}

# Check if a cluster exists.
# Arguments: <version> <cluster>
sub cluster_exists {
    for $c (get_version_clusters $_[0]) {
	return 1 if $c eq $_[1];
    }
    return 0;
}

# Return the next free PostgreSQL port.
sub next_free_port {
    # create list of already used ports
    for $v (get_versions) {
	for $c (get_version_clusters $v) {
	    $p = (get_conf_value $v, $c, 'postgresql.conf', 'port') || $defaultport;
	    push @ports, $p;
	}
    }

    for ($port = $defaultport; ; ++$port) {
	last unless grep { $_ == $port } @ports;
    }

    return $port;
}

# Return the major server version that belongs to the given port. Return undef
# if there is no cluster for this port.
# Arguments: <port>
sub port_version {
    for $v (get_versions) {
	for $c (get_version_clusters $v) {
	    $p = (get_conf_value $v, $c, 'postgresql.conf', 'port') || $defaultport;
	    return $v if $p == $_[0];
	}
    }

    return undef;
}

# Return the PostgreSQL version, cluster, and database to connect to. version
# is always set (defaulting to the version of the default port if no matching
# entry is found), cluster and database may be 'undef'.
sub user_cluster_map {
    my ($user, $pwd, $uid, $gid) = getpwuid $>;
    my $group = (getgrgid  $gid)[0];

    # check per-user configuration file
    $home = $ENV{"HOME"} || (getpwuid $>)[7];
    $homemapfile = $home . '/.postgresqlrc';
    if (open MAP, $homemapfile) {
	while (<MAP>) {
	    s/(.*?)#.*/$1/;
	    next if /^\s*$/;
	    ($v,$c,$db) = split;
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
        ($u,$g,$v,$c,$db) = split;
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

    return (port_version $defaultport, undef, undef);
}
