# Regular cron jobs for the postgresql-common package
#
#[TODO] check the pathnames and the operation of do.maintenance to ensure that this
# correcly vacuums all database clusters
#
# To ensure proper access rights, 'ident sameuser' access for localhost is
# required in /etc/postgresql/pg_hba.conf.  This is now the default setting for
# the Debian configuration.
#
# If password access for local is turned on in /etc/postgresql/<port>/pg_hba.conf,
# you must create a file ~postgres/.pgpass containing a line specifying the
# password, as explained in section 1.11 of the PostgreSQL Programmer's Guide
# (package postgresql-doc8.0).
#
# If autovacuum is turned on in /etc/default/postgresql/<port>, you need
# to give the -F option to do.maintenance for it to do anything.

# Run VACUUM ANALYSE on all databases every 5 hours if pg_autovacuum is not
# running

2 0,5,10,15,20 * * 1-6 postgres	if [ -z "`ps --no-headers -C pg_autovacuum`" -a -x /usr/lib/postgresql/bin/do.maintenance ]; then /usr/lib/postgresql/bin/do.maintenance -a; fi

# On Sunday you may wish to run a VACUUM FULL ANALYSE as well
# If you do not run a 24/7 site, you may want to uncomment the next line
# so as to do a regular VACUUM FULL.  If you need 24/7 connectivity, save 
# VACUUM FULL for when you think you really need it
# 10 3 * * Sun postgres	/usr/bin/test -x /usr/lib/postgresql/8.0/bin/do.maintenance && /usr/lib/postgresql/8.0/bin/do.maintenance -a -f -F
