        List of databases
   Name    |  Owner   | Encoding  
-----------+----------+-----------
 nobodydb  | nobody   | SQL_ASCII
 template0 | postgres | SQL_ASCII
 template1 | postgres | SQL_ASCII
(3 rows)

 name  | tel 
-------+-----
 Bob   |   1
 Alice |   2
(2 rows)

Creating new cluster (configuration: /etc/postgresql/8.0/pg74, data: /var/lib/postgresql/8.0/pg74)...
Moving configuration file /var/lib/postgresql/8.0/pg74/pg_hba.conf to /etc/postgresql/8.0/pg74...
Moving configuration file /var/lib/postgresql/8.0/pg74/pg_ident.conf to /etc/postgresql/8.0/pg74...
Moving configuration file /var/lib/postgresql/8.0/pg74/postgresql.conf to /etc/postgresql/8.0/pg74...
Configuring postgresql.conf to use port 5434...
Dumping the old cluster into the new one...
Copying old configuration files...
Copying old start.conf...
Stopping target cluster...
Stopping old cluster...
Disabling automatic startup of old cluster...
Configuring old cluster to use a different port (5434)...
Starting target cluster on the original port...
Vacuuming and analyzing target cluster...
Doing maintenance on cluster 8.0/pg74...
Success. Please check that the upgraded cluster works. If it does,
you can remove the old cluster with

  pg_dropcluster 7.4 pg74
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     pg74      5434 down   postgres /var/lib/postgresql/7.4/pg74       /var/log/postgresql/postgresql-7.4-pg74.log 
8.0     pg74      5432 online postgres /var/lib/postgresql/8.0/pg74       /var/log/postgresql/postgresql-8.0-pg74.log 
8.0     pg80      5433 online postgres /var/lib/postgresql/8.0/pg80       /var/log/postgresql/postgresql-8.0-pg80.log 
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     pg74      5432 online postgres /var/lib/postgresql/8.0/pg74       /var/log/postgresql/postgresql-8.0-pg74.log 
8.0     pg80      5433 online postgres /var/lib/postgresql/8.0/pg80       /var/log/postgresql/postgresql-8.0-pg80.log 
Default socket directory /var/run/postgresql:
.
..
.s.PGSQL.5433
.s.PGSQL.5433.lock
This cluster's socket directory /tmp/postgresql-testsuite/:
.
..
.s.PGSQL.5432
.s.PGSQL.5432.lock
        List of databases
   Name    |  Owner   | Encoding  
-----------+----------+-----------
 nobodydb  | nobody   | SQL_ASCII
 template0 | postgres | SQL_ASCII
 template1 | postgres | SQL_ASCII
(3 rows)

 name  | tel 
-------+-----
 Bob   |   1
 Alice |   2
(2 rows)

