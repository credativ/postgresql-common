#/*
   pg_default.c
  
   Set defaults for pg_wrapper.
  
   Copyright (c) 2003 Oliver Elphick <olly@lfix.co.uk>
   Licence:  GNU Public Licence v.2 or later

 */

#include "pg_wrapper.h"
#include "pg_vars.h"

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <pwd.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

void show_default(void);
void set_own_default(void);
void set_all_default(void);
void set_group_default(void);
void set_user_default(void);
void set_defaults(void);

/********************************************************************
 Set the defaults requested 
 ********************************************************************/
void set_defaults (void) {
  int uid;

  if (username[0] != '\0' || groupname[0] != '\0' || set_default) {
    /* These options require root privilege or postgres */
    if ((uid = geteuid())) /* id 0 is root */ {
      /* Not root; is it postgres? */
      if (getpwnam("postgres")->pw_uid != uid) {
	fprintf(stderr, "Only the superuser or the user 'postgres' can do that\n");
        exit(LOC_ERR_PERM);
      }
    }
    if (clustername[0] != '\0') {
      if (!valid_cluster(clustername)){
	fprintf(stderr,"Unknown cluster %s\n", clustername);
	exit(LOC_ERR_SYNTAX);
      }
    } else {
      fprintf(stderr,"Cluster not specified\n");
      exit(LOC_ERR_SYNTAX);
    }
    if (username[0] != '\0')
	set_user_default();
    if (groupname[0] != '\0')
	set_group_default();
    if (set_default)
	set_all_default();
  } else {
    if (force || release) {
      fprintf(stderr, "Only the superuser can use -f or -r\n");
      exit(LOC_ERR_PERM);
    }
   if (clustername[0] == '\0' && dbname[0] == '\0') {
     show_default();
   } else {
     set_own_default();
   }
  }
}

void set_user_default(void) {
  write_cluster_line(username, "*", clustername, dbname, force);
}

void set_group_default(void) {
  write_cluster_line("*", groupname, clustername, dbname, force);
}

void set_all_default(void) {
  write_cluster_line("*", "*", clustername, dbname, force);
}

void set_own_default(void) {
  write_rc( clustername, dbname);
}

void show_default(void) {
  char buf[PATHLEN];  /* temporary buffer */
  char ugname[BUFSIZ] = "";
  char sdcluster[BUFSIZ] = "";
  char sddb[BUFSIZ] = "";
  char sdf[BUFSIZ] = "";
  char owncluster[BUFSIZ] = "";
  char owndb[BUFSIZ] = "";
  int ugno, frc;
  struct passwd *pwd;
  
  find_settings(buf);
  if (!(strncmp(dbname, "*", 2)) || dbname[0] == '\0') {
    pwd = getpwuid(getuid());
    strncpy(dbname, pwd->pw_name, BUFSIZ);
  }
  printf("Cluster: %s; database: %s\n", clustername, dbname);
 
  if (verbose) {
    get_sys_default_info(&ugno, ugname, sdcluster, sddb, &frc);
    if (frc) {
      strcpy(sdf, "FORCED");
    }

    switch (ugno) {
    case 1:
      printf("\nSystem defaults for user %s --\n"
	     "  cluster: %s; database: %s   %s\n", 
	     ugname, sdcluster, sddb, sdf);
      break;
    case 2:
      printf("\nSystem defaults for group %s --\n"
	     "  cluster: %s; database: %s   %s\n", 
	     ugname, sdcluster, sddb, sdf);
      break;
    case 4:
      strcpy(sdf, "(cluster for port 5432)");
    case 3:
      printf("\nSystem defaults for unspecified users --\n"
	     "  cluster: %s; database: %s   %s\n", 
	     sdcluster, sddb, sdf);
      break;
    case 0:
      printf("\nNo system default and no cluster for port 5432\n");
    }
    if (!frc) {
      get_user_default_info(owncluster, owndb);
      printf("%s/.postgresqlrc:\n"
	     "  cluster: %s; database: %s\n",
	     getenv("HOME"), owncluster, owndb);

      owncluster[0] = '\0';
      if ((getenv("PGCLUSTER")) != NULL) {
	strncpy(owncluster, getenv("PGCLUSTER"), BUFSIZ);
      }
      owndb[0] = '\0';
      if ((getenv("PGDATABASE")) != NULL) {
	strncpy(owndb, getenv("PGDATABASE"), BUFSIZ);
      }
      if (owncluster[0] != '\0' || owndb[0] != '\0') {
	printf("Environment:\n  PGCLUSTER: %s; PGDATABASE: %s\n",
	       owncluster, owndb);
      }
    }
  }
}
