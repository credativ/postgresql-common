Creating new cluster (configuration: /etc/postgresql/8.0/pg80, data: /var/lib/postgresql/8.0/pg80)...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_hba.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_ident.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/postgresql.conf to /etc/postgresql/8.0/pg80...
Configuring postgresql.conf to use port 5433...
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     pg74      5432 online postgres /var/lib/postgresql/7.4/pg74       /var/log/postgresql/postgresql-7.4-pg74.log 
8.0     pg80      5433 online postgres /var/lib/postgresql/8.0/pg80       /var/log/postgresql/postgresql-8.0-pg80.log 
postgres postgres /usr/lib/postgresql/7.4/bin/postmaster -c unix_socket_directory=/tmp/postgresql-testsuite/ -D /var/lib/postgresql/7.4/pg74
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/pg80 -c config_file=/etc/postgresql/8.0/pg80/postgresql.conf -c hba_file=/etc/postgresql/8.0/pg80/pg_hba.conf -c ident_file=/etc/postgresql/8.0/pg80/pg_ident.conf
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5433 -H /var/run/postgresql -L /var/log/postgresql/pg_autovacuum-8.0-pg80.log
Socket directory:
.
..
.s.PGSQL.5433
.s.PGSQL.5433.lock
psql (PostgreSQL) 8.0.3
contains support for command-line editing
        List of databases
   Name    |  Owner   | Encoding  
-----------+----------+-----------
 template0 | postgres | SQL_ASCII
 template1 | postgres | SQL_ASCII
(2 rows)

