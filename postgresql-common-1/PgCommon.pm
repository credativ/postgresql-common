# Common functions for the postgresql-common framework
# (C) 2005 Martin Pitt <mpitt@debian.org>

package PgCommon;

use Exporter;
$VERSION = 1.00;
@ISA = ('Exporter');
@EXPORT = qw/get_conf_value user_cluster_map get_program_path/;
@EXPORT_OK = qw/$confroot $socket_dir/;

# configuration
$mapfile = "/etc/postgresql-common/user_clusters";
$confroot = "/etc/postgresql";
$binroot = "/usr/lib/postgresql";
$socketdir = "/var/run/postgresql";

# Return parameter from a PostgreSQL configuration file, or '' if the parameter
# does not exist.
# Arguments: <version> <cluster> <parameter name>
sub get_conf_value {
    return 0 unless $_[0] && $_[1];
    open F, "$confroot/$_[0]/$_[1]/postgresql.conf" or die "Could not open configuration file: $!";
    while (<F>) {
        return $1 if /^\s*$_[2]\s*=\s*(\w+)\b/;
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
    return "$binroot/$_[1]/bin/$_[0]";
}
