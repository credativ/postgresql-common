/*
   pg_files.c
  
   File handling for pg_wrapper.c.
  
   Copyright (c) Oliver Elphick <olly@lfix.co.uk> 2003
   Licence:  GNU Public Licence v.2 or later

 */

#include "pg_wrapper.h"
#include "pg_vars.h"

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

extern int h_errno;

char *cluster_by_default_port(void);
char *find_default_cluster(char *db);
char *set_pgport(char *cluster);
int set_version_from_pgdata(char *buf);
void set_version(const char *cluster);
void read_postgresqlrc(char which);
void set_globals (char *uc_db, int frc);

static FILE *cluster_ports;
static FILE *user_clusters;
char *cp_filename = "/etc/postgresql/cluster_ports";
char *uc_filename = "/etc/postgresql/user_clusters";



/********************************************************************
 Finding all the settings.

 Process: 
   1.  Read /etc/postgresql/user_clusters, and get the system default cluster
       for this user.
   2.  If FORCED is not set, the latest of these applies:
       a)  read $HOME/.postgresqlrc for the user default cluster.
       b)  check the environment for PGCLUSTER; use it if it is set.
       c)  if -c {cluster} has been given in the command line, use that.
   3.  Read the cluster line from /etc/postgresql/cluster_ports and set
       PGPORT
   4.  Read the database version from the $PGDATA/PG.VERSION file, if it
       is accessible.  Otherwise use the value from the cluster_ports line.
       This program needs to be suid root to let this happen for every
       database, if any databases are owned by users other than postgres.
   5.  Construct the command pathname using the version as part of the path.
 ********************************************************************/

/********************************************************************
 Find the appropriate settings for this user on this machine.  Generate
 a pathname for the command and write it into the supplied pointer.
 ********************************************************************/
void find_settings(char *path) {
  char buf[BUFSIZ+1] = "";
  char db[BUFSIZ+1] = "";
  char *ptr;
  char emsg[BUFSIZ+1] = "";
  
  if ((user_clusters = fopen(uc_filename, "r")) == NULL) {
    snprintf(emsg, PATHLEN, "Could not open %s", uc_filename);
    perror (emsg);
    exit(LOC_ERR_READ_FAIL);
  }

  if ( (cluster_ports = fopen(cp_filename, "r")) == NULL) {
    snprintf(emsg, PATHLEN, "Could not open %s", cp_filename);
    perror (emsg);
    exit(LOC_ERR_READ_FAIL);
  }

  strcpy(buf, find_default_cluster(db));

  if (force) {
    strncpy(clustername, buf, BUFSIZ);
    strncpy(dbname, db, BUFSIZ);
  } else {
    if (clustername[0] == '\0') { 
      /* not already set on command line */
      read_postgresqlrc(SET_CLUSTER);
      if (getenv("PGCLUSTER")) {
	strncpy(clustername, getenv("PGCLUSTER"), BUFSIZ);
      }
      if (clustername[0] == '\0') {
	strncpy(clustername, buf, BUFSIZ);
      }
    }
    if (dbname[0] == '\0') { 
      /* not already set on command line */
      read_postgresqlrc(SET_DATABASE);
      if (getenv("PGDATABASE")) {
	strncpy(dbname, getenv("PGDATABASE"), BUFSIZ);
      }
      if (dbname[0] == '\0') {
	strncpy(dbname, db, BUFSIZ);
      }
    }
  }

  if (clustername[0] == '\0') {
    fprintf(stderr, "No clusters defined or available to this user\n");
    exit(LOC_ERR_CONFIG);
  }
  set_version(clustername);

  if (!(ptr = set_pgport(clustername))) { /* PGDATA for this cluster */
    fprintf(stderr, "Could not find cluster_ports line for cluster %s\n",
	    clustername);
    exit(LOC_ERR_CONFIG);
  }
  strcpy(buf, ptr);
  /* set the PGDATA environment variable */
  setenv("PGDATA", buf, 1);

  set_version_from_pgdata(buf);
  add_version_to_path(path);

  return;
} /* find_settings() */


/********************************************************************
 Find the default settings for this user.
********************************************************************/

char *find_default_cluster(char *db) {
  char uc_user[BUFSIZ+1] = ""; 
  static char uc_cl[BUFSIZ+1] = "";
  char uc_db[PATHLEN+1] = "";
  int ugno, frc;

  get_sys_default_info(&ugno, uc_user, uc_cl, uc_db, &frc);
  if (strlen(uc_cl)) {
    strcpy(db, uc_db);
    force = frc;
    
    return(uc_cl);
  }
    
  /* No match, so look for a cluster with port 5432 */
  return(cluster_by_default_port());
} /* find_default_cluster */


/********************************************************************
 Find the line in cluster_ports with port 5432
 ********************************************************************/
char *cluster_by_default_port() {
  char line[LINELEN];
  static char cp_cl[BUFSIZ+1] = "";
  char cp_st[BUFSIZ+1] = "";
  char cp_owner[BUFSIZ+1] = "";
  int cp_port;
  char cp_ver[BUFSIZ+1] = "";
  char cp_pgdata[PATHLEN] = "";
  char junk[PATHLEN+1] = "";

  char *ptr;
  char emsg[PATHLEN];

  char *cl_fmt = "%%%ds %%%ds %%%ds %%%ds %%d %%%ds %%%ds %%%ds";
  char fmt[BUFSIZ+1];

  int assigned, cnt = 0;

  snprintf(fmt, BUFSIZ, cl_fmt,
	   BUFSIZ, BUFSIZ, BUFSIZ, BUFSIZ, 
	   BUFSIZ, PATHLEN, PATHLEN);

  fseek(cluster_ports, 0, SEEK_SET);

  while (fgets(line, LINELEN, cluster_ports) != NULL) {
    cnt++;   /* line count */

    /* throw away any comments */
    if ( (ptr = strchr(line, '#')) != NULL)
      *ptr = '\0';

    assigned = sscanf(line, fmt, cp_cl, cp_st, cp_owner,
		      cp_ver, &cp_port, cp_pgdata, junk);
    if (assigned == EOF || assigned == 0) /* comment or blank line */
      continue;

    if (assigned != 6) {
      strcpy (emsg, "wrong number of parameters");
      goto bad_line;
    }

    if (cp_port == 5432)
      return(cp_cl);
  }

  /* we didn't find anything, so make sure we return a null string */
  cp_cl[0] = '\0';

  return(cp_cl);

  
 bad_line: fprintf(stderr, "Bad line %d in %s:\n  %s\n", cnt, cp_filename, emsg);
  exit(LOC_ERR_FILE_FORMAT);
}  /* cluster_by_default_port */


/********************************************************************
 Find values from $HOME/.postgresqlrc -- sets clustername
 ********************************************************************/
void read_postgresqlrc(char which) {
  char cl[BUFSIZ+1], db[BUFSIZ+1];

  cl[0] = '\0';
  db[0] = '\0';

  get_user_default_info(cl, db);
  if (which & SET_CLUSTER) {
    strcpy(clustername, cl);
  }
  if (which & SET_DATABASE) {
    strcpy(dbname, db);
  }
} /* read_postgresqlrc */


/********************************************************************
 Set the value of PGPORT in the environment and return the value of
 PGDATA asssociated with the cluster; returns NULL on error
********************************************************************/
char *set_pgport(char *cluster) {
  static char pgdata[PATHLEN];

  char *cl_fmt = "%%%ds %%%ds %%%ds %%%ds %%d %%%ds %%%ds %%%ds";
  char fmt[BUFSIZ+1];
  char line[LINELEN];
  static char cp_cl[BUFSIZ+1] = "";
  char cp_st[BUFSIZ+1] = "";
  char cp_owner[BUFSIZ+1] = "";
  int cp_port;
  char cp_ver[BUFSIZ+1] = "";
  char cp_pgdata[PATHLEN] = "";
  char junk[PATHLEN+1] = "";

  char *ptr;
  char emsg[PATHLEN];

  int assigned, cnt = 0;

  snprintf(fmt, BUFSIZ, cl_fmt,
	   BUFSIZ, BUFSIZ, BUFSIZ, BUFSIZ, 
	   BUFSIZ, PATHLEN, PATHLEN);

  /* read through cluster_ports to find the port associated with
   * this cluster */
  fseek(cluster_ports, 0, SEEK_SET);


  while (fgets(line, LINELEN, cluster_ports) != NULL) {
    cnt++;   /* line count */

    /* throw away any comments */
    if ( (ptr = strchr(line, '#')) != NULL)
      *ptr = '\0';

    assigned = sscanf(line, fmt, cp_cl, cp_st, cp_owner,
		      cp_ver, &cp_port, cp_pgdata, junk);
    if (assigned == EOF || assigned == 0) /* comment or blank line */
      continue;

    if (assigned != 6) {
      strcpy (emsg, "wrong number of parameters");
      goto bad_line;
    }

    if (! strcmp(cp_cl, cluster)) {
      sprintf(line, "%d", cp_port);
      setenv("PGPORT", line, DO_OVERWRITE);
      strcpy(pgdata, cp_pgdata);
      return(pgdata);
    }
  }

  /* we didn't find anything, so we return NULL */

  return(NULL);

  
 bad_line: fprintf(stderr, "Bad line %d in %s:\n  %s\n", cnt, cp_filename, emsg);
  exit(LOC_ERR_FILE_FORMAT);
  return(NULL);
}  /* set_pgport */


/********************************************************************
 Set version from the cluster_ports line
 *******************************************************************/
void set_version(const char * cluster) {
  char *cl_fmt = "%%%ds %%%ds %%%ds %%%ds %%%ds";
  char fmt[LINELEN];
  char line[LINELEN];
  char cp_cl[BUFSIZ+1] = "";
  char ver[BUFSIZ+1] = "";
  char junk[PATHLEN+1] = "";

  int assigned;

  snprintf(fmt, BUFSIZ, cl_fmt, BUFSIZ, BUFSIZ, BUFSIZ, BUFSIZ, PATHLEN);

  /* read through cluster_ports to find the named cluster */
  fseek(cluster_ports, 0, SEEK_SET);

  while (fgets(line, LINELEN, cluster_ports) != NULL) {
    assigned = sscanf(line, fmt, cp_cl, junk, junk, ver, junk);

    if (! strcmp(cp_cl, cluster)) {
      strncpy(version, ver, BUFSIZ-1);
      return; /* found it! */
    }
  }

}


/********************************************************************
 Read $PGDATA/PG_VERSION to find version; return 1 or 0 on success
 or failure.  (We will frequently fail, because this file is not
 expected to be world-readable.) 
********************************************************************/
int set_version_from_pgdata(char *pgdata) {
  FILE *pgvf;
  char buf[BUFSIZ+1];
  int c;

  snprintf(buf, BUFSIZ, "%s/PG_VERSION", pgdata);

  if ((pgvf = fopen(buf,"r"))) {
    if ((c = fscanf(pgvf,"%s",buf)) == 1) {
      strncpy(version, buf, BUFSIZ);
    }
    fclose(pgvf);
    return c;
  }
  return 0;  /* Failed */
} /* set_version_from_pgdata */


/********************************************************************
 Set global variables - not clustername
********************************************************************/
void set_globals (char *uc_db, int frc) {
  strncpy(dbname, uc_db, BUFSIZ);
  force = frc;

} /* set_globals */


/********************************************************************
 Modify path in the supplied char * by adding the version number
 and 'bin/'.  Put the correct library directory in LD_LIBRARY_PATH.
 ********************************************************************/
void add_version_to_path(char* path) {
  char libpath[BUFSIZ+1] = "/usr/lib/postgresql/";
  char *eptr;

  if (version[0] != '\0') {
    strncat(path, version, BUFSIZ - strlen(path) - 1);
    strcat(path, "/");
    strncat(libpath, version, BUFSIZ - strlen(libpath) - 1);
    strcat(libpath, "/");
  }
  strcat(path, "bin/");
  strcat(libpath, "lib");
  if ( (eptr = getenv("LD_LIBRARY_PATH")) != NULL) {
    if (strlen(eptr) > 0) {
      strncat(libpath, ":", BUFSIZ - strlen(libpath) - 1);
      strncat(libpath, eptr, BUFSIZ - strlen(libpath) - 1);
    }
  }
  setenv("LD_LIBRARY_PATH", libpath, DO_OVERWRITE);
}  

/********************************************************************
 Write a line in user_clusters 
 ********************************************************************/
void write_cluster_line(const char *user, const char *group,
			const char *cluster, const char *db,
			const int forceflag) {
  FILE *ucf;
  char *filename = "/etc/postgresql/user_clusters";
  char *buf, *curpos;
  char *ptr, *fptr;
  char in[BUFSIZ], msg[BUFSIZ];
  char c_user[BUFSIZ], c_group[BUFSIZ], junk[BUFSIZ];
  char line[PATHLEN];
  int c, s, i, origlen, insert = 0, set_def = 0;

  /* create the line to write */
  snprintf(line, PATHLEN, "%-12s %-12s %-18s %-9s %s\n",
	   user, group, cluster,
	  (forceflag ? "yes" : "no"),
	  (db[0] == '\0' ? "*" : db));
  line[PATHLEN - 1] = '\0';
  
  /* start of user_clusters - open read-write */
  sprintf(msg, "Failed to open %s for writing", filename);
  if (!(ucf = fopen(filename, "r+"))) {
    perror(msg);
    exit(LOC_ERR_WRITE_FAIL);
  }

  /* Read it into memory. */
  if ((c = fseek(ucf, 0, SEEK_END)) == -1) {
    perror("Error seeking in user_clusters");
    exit(LOC_ERR_READ_FAIL);
  }
  origlen = ftell(ucf);
  s = strlen(line);
  for (i = 0; i <= s; i++)
    fwrite("\0", 1, 1, ucf);

  if ((s = ftell(ucf)) == -1) {
    perror("Error doing ftell() in user_clusters");
    exit(LOC_ERR_READ_FAIL);
  }

  buf = calloc(s + 2, sizeof(char));

  /* map the file. */
  if ((fptr = (char *) mmap(NULL, s,
	PROT_READ | PROT_WRITE, MAP_SHARED, fileno(ucf), 0)) == (void *) -1) {
    perror("Could not map user_clusters");
    exit(LOC_ERR_READ_FAIL);
  }
  memcpy(buf, fptr, s);
  
  /* Search for the same line and record the start point for writing the
     new one */
  /* Read all users first until we get a match.  If
     there is none, stop at the first group or the default or EOF */
  if ((strcmp(user, "*"))) {
    for (curpos = buf;  *curpos != '\0' && !insert;  curpos += (*curpos != '\0' && !insert ? c : 0)) {
      ptr = strchr(curpos, '\n');
      c = ((!ptr) ? strlen(curpos) : (ptr - curpos)) + 1; /* last line too */
      strncpy(in, curpos, c);
      in[c] = '\0';
      sscanf(in, "%s %s %s", c_user, c_group, junk);
      if (!(strncmp(user, c_user, BUFSIZ))) {
	insert = 1;
      }
      
      /* if we reach the first group entry, skip out of the loop */
      if (!(strncmp(c_user, "*", BUFSIZ))) {
	insert = 2;
      }
    }
  } else {
    /* look for the matching group or stop at the default entry or EOF */
    set_def = (strncmp(group, "*", 2) == 0);
    for (curpos = buf; *curpos != '\0' && !insert; curpos += (*curpos != '\0' && !insert ? c : 0)) {
      ptr = (strchr(curpos,'\n'));
      c = ((!ptr) ? strlen(curpos) : (ptr - curpos))+1; /* last line too */
      strncpy(in, curpos, c);
      in[c] = '\0';
      sscanf(in, "%s %s %s", c_user, c_group, junk);
      if (strcmp(c_user, "*")) { /* skip all the user lines first */
	continue;
      }
      if (!(strncmp(group, c_group, BUFSIZ))) {
	insert = 1;
      }
      /* make sure we write a new group before the default line */
      if (!set_def && !strncmp(c_group, "*", 2)) {
	insert = 2;
      }
    }
  }

  /* Either we have found an existing user or group to replace, or we have
     a new line to insert.  If so far we have neither, we must be adding a
     new default line. */
  if (!insert) {
    insert = 3;
  }
  if (insert > 1) {
    /* insert a new line at the current position */
    if (*curpos != '\0') {
      /* move rest of file to leave the correct space for the new line */
      memmove(curpos + strlen(line), curpos, strlen(curpos));
    }
    origlen += strlen(line);
  } else {
    /* overwrite */
    ptr = strchr(curpos, '\n'); /* (drop end of line comments */
    c = (ptr ? ptr - curpos + 1 : strlen(curpos)); /* length of old line */
    i = strlen(line) - c; /* negative means line shrinks */
    memmove(curpos + i, curpos, c);
    if (i < 0) {
      origlen += i;
      ptr = buf + (origlen + 1);
      *ptr = '\0';  /* to mark the new end of file */
    }
  }

  /* write new line at start position (up to end position).  If this is a
   new line at the end, include the NUL byte, so that we know where the
  end of file is. */
  memcpy(curpos, line, strlen(line) + (insert == 3 ? 1 : 0));
  memcpy(fptr, buf, s);

  /* commit the file */
  c = (curpos - buf); /* start offset */
  c = (c / getpagesize()) * getpagesize(); /* align on page boundary */
  ptr = fptr + (c);

  if (msync(ptr, s - c, MS_INVALIDATE & MS_SYNC) == -1) {
    perror("Failed to write new user_clusters file");
    exit(LOC_ERR_WRITE_FAIL);
  }
  munmap(fptr, s);
  s = strlen(buf);
  ftruncate(fileno(ucf), s);
  fclose(ucf);
}


/********************************************************************
 Write the user's own rcfile.  Its existing contents are destroyed
 ********************************************************************/
void write_rc(const char *clustername, const char *dbname) {
  FILE * rcf;
  char filename[BUFSIZ+1];
  char scratch[BUFSIZ+1];

  snprintf(filename, BUFSIZ, "%s/%s", getenv("HOME"), ".postgresqlrc");
  snprintf(scratch, BUFSIZ, "Failed to open %s for writing", filename);
  if (!(rcf = fopen(filename, "w"))) {
    perror(scratch);
    exit(LOC_ERR_WRITE_FAIL);
  }
  fprintf(rcf,"cluster = %s\ndatabase = %s\n", clustername, dbname);
  fclose(rcf);
}


/*********************************************************************
  Get the default information from user_clusters and put it in the passed
  buffers
 *********************************************************************/
void get_sys_default_info(int *type, char *name,
			  char *cluster, char *database, int *frc) {

  char line[LINELEN];

  char uc_user[BUFSIZ+1] = ""; 
  char uc_grp[BUFSIZ+1] = "";
  static char uc_cl[BUFSIZ+1] = "";
  char uc_frc[BUFSIZ+1] = "";
  char uc_db[PATHLEN+1] = "";
  char junk[PATHLEN+1] = "";

  char emsg[PATHLEN];

  char *uc_fmt = "%%%ds %%%ds %%%ds %%%ds %%%ds %%%ds";
  char fmt[BUFSIZ+1];
  char *ptr;
  char *filename = uc_filename;
  
  char cur_user[BUFSIZ+1] = "";
  char cur_group[BUFSIZ+1] = "";

  struct passwd *pwd;
  struct group *grp;

  pwd = getpwuid(getuid());
  grp = getgrgid(getgid());

  strncpy(cur_user, pwd->pw_name, BUFSIZ);
  strncpy(cur_group, grp->gr_name, BUFSIZ);

  int assigned, cnt = 0;

  snprintf(fmt, PATHLEN, uc_fmt, BUFSIZ, BUFSIZ, BUFSIZ, BUFSIZ, BUFSIZ, PATHLEN);
  fseek(user_clusters, 0, SEEK_SET);

  while (fgets(line, LINELEN, user_clusters) != NULL) {
    cnt++;   /* line count */

    /* throw away any comments */
    if ( (ptr = strchr(line, '#')) != NULL)
      *ptr = '\0';

    assigned = sscanf(line, fmt, uc_user, uc_grp, uc_cl, uc_frc, uc_db, junk);
    if (assigned == EOF || assigned == 0) /* comment or blank line */
      continue;

    if (assigned != 5) {
      strcpy (emsg, "wrong number of parameters");
      goto bad_line;
    }

    /* The default database is the one of the user's login name */
    if (!strcmp(uc_db, "*"))
      strcpy(uc_db, cur_user);

    /* set the error message in case it is needed */
    snprintf (emsg, PATHLEN, "word '%s': unrecognised value for FORCED", uc_frc);
    /* convert forced parameter to lower case */
    for (ptr = uc_frc; *ptr != '\0'; ptr++)
      *ptr = (*ptr >= 'A' && *ptr <= 'Z' ? (*ptr + 32) : *ptr);

    if ( (! strcmp(uc_frc, "yes")) || (! strcmp(uc_frc, "true")) || (! strcmp(uc_frc, "on"))) {
      *frc = 1;
    } else if ( (! strcmp(uc_frc, "no")) || (! strcmp(uc_frc, "false")) || (! strcmp(uc_frc, "off"))) {
      *frc = 0;
    } else {
      goto bad_line;
    }

    if (! strcmp(uc_user, cur_user)) {
      /* user matches (group is ignored) */
      *type = 1;
      strncpy(name, cur_user, BUFSIZ-1);
      name[BUFSIZ] = '\0';
      strncpy(cluster, uc_cl, BUFSIZ-1);
      cluster[BUFSIZ] = '\0';
      strncpy(database, uc_db, BUFSIZ-1);
      database[BUFSIZ] = '\0';

      return;
    }
    if ((! strcmp("*", uc_user)) &&
	(! strcmp(uc_grp, cur_group) || (! strcmp("*", uc_grp)))) {
      /* user wildcard and group matches or is wildcard */
      if (! strcmp(uc_grp, cur_group)) {
	*type = 2;  /* group matched */
      } else {
	*type = 3;  /* system default */
      }
      strncpy(name, uc_grp, BUFSIZ-1);
      name[BUFSIZ] = '\0';
      strncpy(cluster, uc_cl, BUFSIZ-1);
      cluster[BUFSIZ] = '\0';
      strncpy(database, uc_db, BUFSIZ-1);
      database[BUFSIZ] = '\0';
      return;
    }
  }
  
  /* No match, so look for a cluster with port 5432 */
  strcpy(database, "*");
  if ((ptr = cluster_by_default_port()))
    strncpy(cluster, ptr, BUFSIZ-1);
  cluster[BUFSIZ] = '\0';
  *type = (cluster[0] ? 4 : 0);
  return;

 bad_line: fprintf(stderr, "Bad line %d in %s:\n  %s\n", cnt, filename, emsg);
  exit(LOC_ERR_FILE_FORMAT);
}

/*********************************************************************
  Get the user's own default information and put it in the passed buffers
 *********************************************************************/
void get_user_default_info(char *cluster, char * database) {
  FILE *rcfile;
  char filename[PATHLEN] = "";
  char line[LINELEN];
  char *fmt = "%s = %s";
  char *ptr;
  char parname[PATHLEN], parvalue[PATHLEN];
  int assigned, cnt = 0;

  strncpy(filename, getenv("HOME"), PATHLEN);
  strncat(filename, "/.postgresqlrc", PATHLEN - strlen(filename));

  if ((rcfile = fopen(filename, "r")) == NULL)
    return;    /* no file -- so return now */

  
  while (fgets(line, LINELEN, rcfile) != NULL) {
    cnt++;   /* line count */

    /* throw away any comments */
    if ( (ptr = strchr(line, '#')) != NULL)
      *ptr = '\0';

    assigned = sscanf(line, fmt, parname, parvalue);
    if (assigned == EOF || assigned == 0) /* comment or blank line */
      continue;

    if (assigned == 2) {
      if (!strcmp(parname, "cluster"))
	strncpy(cluster, parvalue, BUFSIZ);

      if (!strcmp(parname, "database"))
	strncpy(database, parvalue, BUFSIZ);
    }
  }
  fclose(rcfile);
  return;
}

/*********************************************************************
 * valid_cluster() returns true if the cluster exists in cluster_ports
 *********************************************************************/
int    valid_cluster(const char *cluster) {
  char *cl_fmt = "%%%ds %%%ds";
  char fmt[LINELEN];
  char line[LINELEN];
  static char cp_cl[BUFSIZ+1] = "";
  char junk[PATHLEN+1] = "";

  int assigned;

  snprintf(fmt, BUFSIZ, cl_fmt, BUFSIZ, PATHLEN);

  /* read through cluster_ports to find the named cluster */
  fseek(cluster_ports, 0, SEEK_SET);

  while (fgets(line, LINELEN, cluster_ports) != NULL) {
    assigned = sscanf(line, fmt, cp_cl, junk);

    if (! strcmp(cp_cl, cluster)) {
      return(1); /* found it! */
    }
  }

  /* we didn't find anything, so we return false */

  return(0);
}
