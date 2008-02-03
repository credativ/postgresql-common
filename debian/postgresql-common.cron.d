# Regular cron jobs for the postgresql-common package
#
# To ensure proper access rights, 'ident sameuser' access for
# localhost is required in all cluster's pg_hba.conf.  This is the
# default setting for new clusters created with pg_createcluster.
#
# If password access for local is turned on in
# /etc/postgresql/<version>/<cluster>/pg_hba.conf, you must create a file 
# <cluster owner home directory>/.pgpass containing a line specifying
# the password, as explained in the PostgreSQL Manual, section 30.13
# (if you have postgresql-doc-8.3 installed, you can find that part of
# the manual in /usr/share/doc/postgresql-doc-8.3/html/libpq-pgpass.html).

# Run VACUUM ANALYSE on all databases every 5 hours if pg_autovacuum is not
# running
2 0,5,10,15,20 * * 1-6 root if [ -x /usr/sbin/pg_maintenance ]; then /usr/sbin/pg_maintenance --analyze >/dev/null; fi

# In rare circumstances you might wish to regularly run VACUUM FULL
# ANALYSE as well. This is not generally recommended, though, and
# can have a drastic detrimental effect on database performance and
# index size. Please read and understand 
# /usr/share/doc/postgresql-doc-8.3/html/routine-vacuuming.html first
# before enabling this.
# 10 3 * * Sun root if [ -x /usr/sbin/pg_maintenance ]; then /usr/sbin/pg_maintenance --full --analyze >/dev/null; fi
