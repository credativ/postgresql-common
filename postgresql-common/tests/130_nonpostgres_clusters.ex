Creating new cluster (configuration: /etc/postgresql/7.4/pg74, data: /var/lib/postgresql/7.4/pg74)...
Moving configuration file /var/lib/postgresql/7.4/pg74/pg_hba.conf to /etc/postgresql/7.4/pg74...
Moving configuration file /var/lib/postgresql/7.4/pg74/pg_ident.conf to /etc/postgresql/7.4/pg74...
Moving configuration file /var/lib/postgresql/7.4/pg74/postgresql.conf to /etc/postgresql/7.4/pg74...
Configuring postgresql.conf to use port 5432...
Warning: The socket directory for owners other than 'postgres'
defaults to /tmp. You might want to change the unix_socket_directory parameter
in postgresql.conf to a more secure directory.
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     pg74      5432 online nobody   /var/lib/postgresql/7.4/pg74       /var/log/postgresql/postgresql-7.4-pg74.log 
nobody   nogroup  /usr/lib/postgresql/7.4/bin/postmaster -c unix_socket_directory=/tmp -D /var/lib/postgresql/7.4/pg74
USER     GROUP    COMMAND
Socket directory:
/tmp/.s.PGSQL.5432
/tmp/.s.PGSQL.5432.lock

/var/run/postgresql/:
.
..
       List of databases
   Name    | Owner  | Encoding  
-----------+--------+-----------
 template0 | nobody | SQL_ASCII
 template1 | nobody | SQL_ASCII
(2 rows)

Version Cluster   Port Status Owner    Data directory                     Log file                       
USER     GROUP    COMMAND
Creating new cluster (configuration: /etc/postgresql/8.0/pg80, data: /var/lib/postgresql/8.0/pg80)...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_hba.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/pg_ident.conf to /etc/postgresql/8.0/pg80...
Moving configuration file /var/lib/postgresql/8.0/pg80/postgresql.conf to /etc/postgresql/8.0/pg80...
Configuring postgresql.conf to use port 5432...
Warning: The socket directory for owners other than 'postgres'
defaults to /tmp. You might want to change the unix_socket_directory parameter
in postgresql.conf to a more secure directory.
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     pg80      5432 online nobody   /var/lib/postgresql/8.0/pg80       /var/log/postgresql/postgresql-8.0-pg80.log 
nobody   nogroup  /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/pg80 -c unix_socket_directory=/tmp -c config_file=/etc/postgresql/8.0/pg80/postgresql.conf -c hba_file=/etc/postgresql/8.0/pg80/pg_hba.conf -c ident_file=/etc/postgresql/8.0/pg80/pg_ident.conf
USER     GROUP    COMMAND
nobody   nogroup  /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5432 -H /tmp -L /var/log/postgresql/pg_autovacuum-8.0-pg80.log
Socket directory:
/tmp/.s.PGSQL.5432
/tmp/.s.PGSQL.5432.lock

/var/run/postgresql/:
.
..
       List of databases
   Name    | Owner  | Encoding  
-----------+--------+-----------
 template0 | nobody | SQL_ASCII
 template1 | nobody | SQL_ASCII
(2 rows)

Version Cluster   Port Status Owner    Data directory                     Log file                       
USER     GROUP    COMMAND
