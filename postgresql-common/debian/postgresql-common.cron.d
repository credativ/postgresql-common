# Regular cron jobs for the postgresql-common package
#
# To ensure proper access rights, 'ident sameuser' access for
# localhost is required in all cluster's pg_hba.conf.  This is the
# default setting for new clusters created with pg_createcluster.
#
# If password access for local is turned on in
# /etc/postgresql/<port>/pg_hba.conf, you must create a file 
# <cluster owner home directory>/.pgpass containing a line specifying
# the password, as explained in the PostgreSQL Manual, section 27.12
# (in package postgresql-doc-8.0).

# Run VACUUM ANALYSE on all databases every 5 hours if pg_autovacuum is not
# running
2 0,5,10,15,20 * * 1-6 root if [ -x /usr/sbin/pg_maintenance ]; then /usr/sbin/pg_maintenance --analyze >/dev/null; fi

# On Sunday you may wish to run a VACUUM FULL ANALYSE as well
# If you do not run a 24/7 site, you may want to uncomment the next line
# so as to do a regular VACUUM FULL.  If you need 24/7 connectivity, save 
# VACUUM FULL for when you think you really need it.
# 10 3 * * Sun root if [ -x /usr/sbin/pg_maintenance ]; then /usr/sbin/pg_maintenance --full --analyze >/dev/null; fi
