Creating new cluster (configuration: /etc/postgresql/8.0/pg80, data: /var/lib/postgresql/8.0/pg80)...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_hba.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_ident.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/postgresql.conf to /etc/postgresql/8.0/pg80...
Configuring postgresql.conf to use port 5433...
Version Cluster   Port Status Owner    Data directory                     Log file                      
7.4     pg74      5432 online postgres /var/lib/postgresql/7.4/pg74       /var/log/postgresql/postgresql-7.4-pg74.log
8.0     pg80      5433 online postgres /var/lib/postgresql/8.0/pg80       /var/log/postgresql/postgresql-8.0-pg80.log
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/7.4/bin/postmaster -D /var/lib/postgresql/7.4/pg74
postgres postgres postgres: stats buffer process                                        
postgres postgres postgres: stats collector process                                     
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/pg80 -c config_file=/etc/postgresql/8.0/pg80/postgresql.conf -c hba_file=/etc/postgresql/8.0/pg80/pg_hba.conf -c ident_file=/etc/postgresql/8.0/pg80/pg_ident.conf
postgres postgres postgres: writer process                                                                                                                                                                                                            
postgres postgres postgres: stats buffer process                                                                                                                                                                                                      
postgres postgres postgres: stats collector process                                                                                                                                                                                                   
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5433 -H /var/run/postgresql
Socket directory:
.
..
.s.PGSQL.5432
.s.PGSQL.5432.lock
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

