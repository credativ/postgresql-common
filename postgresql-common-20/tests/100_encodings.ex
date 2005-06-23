*** creating 8.0 cluster with locale en_US and default encoding ***
Creating new cluster (configuration: /etc/postgresql/8.0/en_US, data: /var/lib/postgresql/8.0/en_US)...
Moving configuration file /var/lib/postgresql/8.0/en_US/pg_hba.conf to /etc/postgresql/8.0/en_US...
Moving configuration file /var/lib/postgresql/8.0/en_US/pg_ident.conf to /etc/postgresql/8.0/en_US...
Moving configuration file /var/lib/postgresql/8.0/en_US/postgresql.conf to /etc/postgresql/8.0/en_US...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     en_US     5432 online postgres /var/lib/postgresql/8.0/en_US      /var/log/postgresql/postgresql-8.0-en_US.log 
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/en_US -c config_file=/etc/postgresql/8.0/en_US/postgresql.conf -c hba_file=/etc/postgresql/8.0/en_US/pg_hba.conf -c ident_file=/etc/postgresql/8.0/en_US/pg_ident.conf
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5432 -H /var/run/postgresql -L /var/log/postgresql/pg_autovacuum-8.0-en_US.log
locales of postmaster server processes:
LC_ALL=en_US
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | LATIN1
 template1 | postgres | LATIN1
(2 rows)

LC_COLLATE:                           en_US
LC_CTYPE:                             en_US

*** creating 8.0 cluster with locale en_US and encoding UTF-8 ***
Creating new cluster (configuration: /etc/postgresql/8.0/UTF-8, data: /var/lib/postgresql/8.0/UTF-8)...
initdb: warning: encoding mismatch
The encoding you selected (UNICODE) and the encoding that the selected
locale uses (ISO-8859-1) are not known to match.  This may lead to
misbehavior in various character string processing functions.  To fix
this situation, rerun initdb and either do not specify an encoding
explicitly, or choose a matching combination.
Moving configuration file /var/lib/postgresql/8.0/UTF-8/pg_hba.conf to /etc/postgresql/8.0/UTF-8...
Moving configuration file /var/lib/postgresql/8.0/UTF-8/pg_ident.conf to /etc/postgresql/8.0/UTF-8...
Moving configuration file /var/lib/postgresql/8.0/UTF-8/postgresql.conf to /etc/postgresql/8.0/UTF-8...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     UTF-8     5432 online postgres /var/lib/postgresql/8.0/UTF-8      /var/log/postgresql/postgresql-8.0-UTF-8.log 
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/UTF-8 -c config_file=/etc/postgresql/8.0/UTF-8/postgresql.conf -c hba_file=/etc/postgresql/8.0/UTF-8/pg_hba.conf -c ident_file=/etc/postgresql/8.0/UTF-8/pg_ident.conf
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5432 -H /var/run/postgresql -L /var/log/postgresql/pg_autovacuum-8.0-UTF-8.log
locales of postmaster server processes:
LC_ALL=en_US
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | UNICODE
 template1 | postgres | UNICODE
(2 rows)

LC_COLLATE:                           en_US
LC_CTYPE:                             en_US

*** creating 8.0 cluster with locale en_US.UTF-8 and default encoding ***
Creating new cluster (configuration: /etc/postgresql/8.0/en_US.UTF-8, data: /var/lib/postgresql/8.0/en_US.UTF-8)...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/pg_hba.conf to /etc/postgresql/8.0/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/pg_ident.conf to /etc/postgresql/8.0/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/postgresql.conf to /etc/postgresql/8.0/en_US.UTF-8...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     en_US.UTF-8 5432 online postgres /var/lib/postgresql/8.0/en_US.UTF-8 /var/log/postgresql/postgresql-8.0-en_US.UTF-8.log 
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/en_US.UTF-8 -c config_file=/etc/postgresql/8.0/en_US.UTF-8/postgresql.conf -c hba_file=/etc/postgresql/8.0/en_US.UTF-8/pg_hba.conf -c ident_file=/etc/postgresql/8.0/en_US.UTF-8/pg_ident.conf
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5432 -H /var/run/postgresql -L /var/log/postgresql/pg_autovacuum-8.0-en_US.UTF-8.log
locales of postmaster server processes:
LC_ALL=en_US.UTF-8
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | UNICODE
 template1 | postgres | UNICODE
(2 rows)

LC_COLLATE:                           en_US.UTF-8
LC_CTYPE:                             en_US.UTF-8

*** creating 7.4 cluster with locale en_US and default encoding ***
Creating new cluster (configuration: /etc/postgresql/7.4/en_US, data: /var/lib/postgresql/7.4/en_US)...
Moving configuration file /var/lib/postgresql/7.4/en_US/pg_hba.conf to /etc/postgresql/7.4/en_US...
Moving configuration file /var/lib/postgresql/7.4/en_US/pg_ident.conf to /etc/postgresql/7.4/en_US...
Moving configuration file /var/lib/postgresql/7.4/en_US/postgresql.conf to /etc/postgresql/7.4/en_US...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     en_US     5432 online postgres /var/lib/postgresql/7.4/en_US      /var/log/postgresql/postgresql-7.4-en_US.log 
postgres postgres /usr/lib/postgresql/7.4/bin/postmaster -c unix_socket_directory=/var/run/postgresql -D /var/lib/postgresql/7.4/en_US
USER     GROUP    COMMAND
locales of postmaster server processes:
LC_ALL=en_US
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | LATIN1
 template1 | postgres | LATIN1
(2 rows)

LC_COLLATE:                           en_US
LC_CTYPE:                             en_US

*** creating 7.4 cluster with locale en_US and encoding UTF-8 ***
Creating new cluster (configuration: /etc/postgresql/7.4/UTF-8, data: /var/lib/postgresql/7.4/UTF-8)...
Moving configuration file /var/lib/postgresql/7.4/UTF-8/pg_hba.conf to /etc/postgresql/7.4/UTF-8...
Moving configuration file /var/lib/postgresql/7.4/UTF-8/pg_ident.conf to /etc/postgresql/7.4/UTF-8...
Moving configuration file /var/lib/postgresql/7.4/UTF-8/postgresql.conf to /etc/postgresql/7.4/UTF-8...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     UTF-8     5432 online postgres /var/lib/postgresql/7.4/UTF-8      /var/log/postgresql/postgresql-7.4-UTF-8.log 
postgres postgres /usr/lib/postgresql/7.4/bin/postmaster -c unix_socket_directory=/var/run/postgresql -D /var/lib/postgresql/7.4/UTF-8
USER     GROUP    COMMAND
locales of postmaster server processes:
LC_ALL=en_US
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | UNICODE
 template1 | postgres | UNICODE
(2 rows)

LC_COLLATE:                           en_US
LC_CTYPE:                             en_US

*** creating 7.4 cluster with locale en_US.UTF-8 and default encoding ***
Creating new cluster (configuration: /etc/postgresql/7.4/en_US.UTF-8, data: /var/lib/postgresql/7.4/en_US.UTF-8)...
Moving configuration file /var/lib/postgresql/7.4/en_US.UTF-8/pg_hba.conf to /etc/postgresql/7.4/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/7.4/en_US.UTF-8/pg_ident.conf to /etc/postgresql/7.4/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/7.4/en_US.UTF-8/postgresql.conf to /etc/postgresql/7.4/en_US.UTF-8...
Configuring postgresql.conf to use port 5432...
Version Cluster   Port Status Owner    Data directory                     Log file                       
7.4     en_US.UTF-8 5432 online postgres /var/lib/postgresql/7.4/en_US.UTF-8 /var/log/postgresql/postgresql-7.4-en_US.UTF-8.log 
postgres postgres /usr/lib/postgresql/7.4/bin/postmaster -c unix_socket_directory=/var/run/postgresql -D /var/lib/postgresql/7.4/en_US.UTF-8
USER     GROUP    COMMAND
locales of postmaster server processes:
LC_ALL=en_US.UTF-8
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | UNICODE
 template1 | postgres | UNICODE
(2 rows)

LC_COLLATE:                           en_US.UTF-8
LC_CTYPE:                             en_US.UTF-8

Creating new cluster (configuration: /etc/postgresql/8.0/en_US.UTF-8, data: /var/lib/postgresql/8.0/en_US.UTF-8)...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/pg_hba.conf to /etc/postgresql/8.0/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/pg_ident.conf to /etc/postgresql/8.0/en_US.UTF-8...
Moving configuration file /var/lib/postgresql/8.0/en_US.UTF-8/postgresql.conf to /etc/postgresql/8.0/en_US.UTF-8...
Configuring postgresql.conf to use port 5433...
Dumping the old cluster into the new one...
Copying old configuration files...
Stopping target cluster...
Stopping old cluster...
Configuring old cluster to use a different port (5433)...
Starting target cluster on the original port...
Success. Please check that the upgraded cluster works. If it does,
you can remove the old cluster with

  pg_dropcluster 7.4 en_US.UTF-8
Version Cluster   Port Status Owner    Data directory                     Log file                       
8.0     en_US.UTF-8 5432 online postgres /var/lib/postgresql/8.0/en_US.UTF-8 /var/log/postgresql/postgresql-8.0-en_US.UTF-8.log 
postgres postgres /usr/lib/postgresql/8.0/bin/postmaster -D /var/lib/postgresql/8.0/en_US.UTF-8 -c config_file=/etc/postgresql/8.0/en_US.UTF-8/postgresql.conf -c hba_file=/etc/postgresql/8.0/en_US.UTF-8/pg_hba.conf -c ident_file=/etc/postgresql/8.0/en_US.UTF-8/pg_ident.conf
USER     GROUP    COMMAND
postgres postgres /usr/lib/postgresql/8.0/bin/pg_autovacuum -p 5432 -H /var/run/postgresql -L /var/log/postgresql/pg_autovacuum-8.0-en_US.UTF-8.log
locales of postmaster server processes:
LC_ALL=en_US.UTF-8
LC_COLLATE=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
        List of databases
   Name    |  Owner   | Encoding 
-----------+----------+----------
 template0 | postgres | UNICODE
 template1 | postgres | UNICODE
(2 rows)

LC_COLLATE:                           en_US.UTF-8
LC_CTYPE:                             en_US.UTF-8
