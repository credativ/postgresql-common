# Common functions for the postgresql-common framework
# (C) 2005 Martin Pitt <mpitt@debian.org>

package PgCommon;

use Exporter;
$VERSION = 1.00;
@ISA = ('Exporter');
@EXPORT = qw/error get_conf_value user_cluster_map get_program_path cluster_info get_versions get_version_clusters/;
@EXPORT_OK = qw/$confroot $socket_dir/;

# configuration
$mapfile = "/etc/postgresql-common/user_clusters";
$confroot = "/etc/postgresql";
$binroot = "/usr/lib/postgresql";
$socketdir = "/var/run/postgresql";
$logdir = "/var/log/postgresql";
$defaultport = 5432;

# Print an error message to stderr and exit with status 1
sub error {
    print STDERR 'Error: ', $_[0], "\n";
    exit 1;
}

# Return parameter from a PostgreSQL configuration file, or '' if the parameter
# does not exist.
# Arguments: <version> <cluster> <parameter name>
sub get_conf_value {
    return 0 unless $_[0] && $_[1];
    if (open F, "$confroot/$_[0]/$_[1]/postgresql.conf") {
        while (<F>) {
            return $1 if /^\s*$_[2]\s*=\s*(\w+)\b/;
        }
        close F;
    }
    return '';
}

# Return the PostgreSQL version, cluster, and database to connect to. Return
# ("","","") if $mapfile does not exist or has no entry for the current user
sub user_cluster_map {
    my ($user, $pwd, $uid, $gid) = getpwuid $>;
    my $group = (getgrgid  $gid)[0];

    if (! open MAP, $mapfile) {
        print "Warning: could not open $mapfile, connecting to default port\n";
        return ('','',$user);
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
            return ($v,$c, ($db eq "*") ? '' : $db);
        }
    }
    return ('','','');
}

# Return the path of a program of a particular version.
# Arguments: <program name> <version>
sub get_program_path {
    my $path = "$binroot/$_[1]/bin/$_[0]";
    return $path if -x $path;
    return '';
}

# Return a hash with information about a specific cluster.
# Arguments: <version> <cluster name>
# Returns: information hash (keys: pgdata, port, running, logfile, configdir,
# owneruid, ownergid)
sub cluster_info {
    $result{'configdir'} = "$confroot/$_[0]/$_[1]";
    $result{'pgdata'} = readlink $result{'configdir'} . "/pgdata";
    $result{'port'} = (get_conf_value $_[0], $_[1], 'port') || $defaultport;
    $result{'running'} = -S "$socketdir/.s.PGSQL." . $result{'port'};
    $result{'logfile'} = "$logdir/postgresql-$_[0]-$_[1].log";
    ($result{'owneruid'}, $result{'ownergid'}) = 
        (stat $result{'pgdata'})[4,5];
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

# Return an array of all available clusters of given version
# Arguments: <version>
sub get_version_clusters {
    my $vdir = $confroot.'/'.$_[0].'/';
    my @clusters = ();
    if (opendir (D, $vdir)) {
        while (defined ($f = readdir D)) {
            push @clusters, $f if -l $vdir.$f.'/pgdata';
        }
        closedir D;
    }
    return @clusters;
}
