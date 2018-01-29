Multi-Version/Multi-Cluster PostgreSQL architecture
===================================================
2004, Oliver Elphick, Martin Pitt

Solving a problem
-----------------

When a new major version of PostgreSQL is released, it is necessary to dump and
reload the database. The old software must be used for the dump, and the new
software for the reload.

This was a major problem for RedHat and Debian, because a dump and reload was
not required by every upgrade and by the time the need for a dump is realised,
the old software might have been deleted. Debian had certain rather unreliable
procedures to save the old software and use it to do a dump, but these
procedures often went wrong. RedHat's installation environment is so rigid that
it is not practicable for the RedHat packages to attempt an automatic upgrade.
Debian offered a debconf choice for whether to attempt automatic upgrading; if
it failed or was not allowed, a manual upgrade had to be done, either from a
pre-existing dump or by manual invocation of the postgresql-dump script.

It is possible to run different versions of PostgreSQL simultaneously, and
indeed to run the same version on separate database clusters simultaneously. To
do so, each postgres instance must listen on a different port, so each client
must specify the correct port. By having two separate versions of the
PostgreSQL packages installed simultaneously, it is simple to do database
upgrades by dumping from the old version and uploading to the new. The
PostgreSQL client wrapper is designed to permit this.

General Architecture idea
-------------------------

The Debian packaging has been changed to create a new package for each major
version. The criterion for creating a new package is that initdb is required
when upgrading from the previous version. Thus, there are now source packages
`postgresql-8.1` and `postgresql-8.3` (and similarly for all the binary
packages).

The legacy postgresql and the other existing binary package names have become
dummy packages depending on one of the versioned equivalents. Their only
purpose is now to ensure a smooth upgrade and to register the existing database
cluster to the new architecture. These packages will be removed from the
archive as soon as the next Debian release after Sarge (Etch) is released.

Each versioned package installs into `/usr/lib/postgresql/version`.  In order
to allow users easily to select the right version and cluster when working, the
`postgresql-common` package provides the `pg_wrapper` program, which reads the
per-user and system wide configuration file and forks the correct executable
with the correct library versions according to those preferences.  `/usr/bin`
provides executables soft-linked to `pg_wrapper`.

This architecture also allows separate database clusters to be maintained for
the use of different groups of users; these clusters need not all be of the
same major version.  This allows much greater flexibility for those people who
need to make application software changes consequent on a PostgreSQL upgrade.

Detailed structure
------------------

### Configuration hierarchy

* `/etc/postgresql-common/user_clusters`: maps users against clusters and
  default databases

* `$HOME/.postgresqlrc`: per-user preferences for default version/cluster and
  database; overrides `/etc/postgresql-common/user_clusters`

* `/etc/postgresql/version/clustername`: cluster-specific configuration files:

  * `postgresql.conf`, `pg_hba.conf`, `pg_ident.conf`
  * optionally `start.conf`: startup mode of the cluster: `auto` (start/stop in
    init script), `manual` (do not start/stop in init script, but manual
    control with `pg_ctlcluster` is possible), `disabled` (`pg_ctlcluster`
    is not allowed).
  * optionally `pg_ctl.conf`: options to be passed to `pg_ctl`.
  * optionally a symbolic link `log` which points to the postgres log file.
    Defaults to `/var/log/postgresql/postgresql-version-cluster.conf`.
    Explicitly setting `log_directory` and/or `log_filename` in
    `postgresql.conf` overrides this.

### Per-version files and programs

* `/usr/lib/postgresql/version`
* `/usr/share/postgresql/version`
* `/usr/share/doc/postgresql/postgresql-doc-version`:
version specific program and data files

### Common programs

* `/usr/share/postgresql-common/pg_wrapper`: environment chooser and program selector
* `/usr/bin/program`: symbolic links to pg_wrapper, for all client programs
* `/usr/bin/pg_lsclusters`: list all available clusters with their status and configuration
* `/usr/bin/pg_createcluster: wrapper for `initdb`, sets up the necessary configuration structure
* `/usr/bin/pg_ctlcluster`: wrapper for `pg_ctl`, control the cluster postgres server
* `/usr/bin/pg_upgradecluster`: upgrade a cluster to a newer major version
* `/usr/bin/pg_dropcluster`: remove a cluster and its configuration

### /etc/init.d/postgresql

This script handles the postgres server processes for each version and all
their clusters. However, most of the actual work is done by the new
`pg_ctlcluster` program.

### pg_upgradecluster

This program replaces postgresql-dump (a Debian specific program).

It is used to migrate a cluster from one major version to another.

Usage: `pg_upgradecluster [-v newversion] version name [data_dir]`

`-v`: specifies the version to upgrade to; defaults to the newest available version.

 -- The Debian PostgreSQL maintainers
