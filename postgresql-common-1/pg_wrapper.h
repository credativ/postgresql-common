/*
   pg_wrapper.h
  
   Header file for pg_wrapper.c and associated files
  
   Copyright (c) Oliver Elphick <olly@lfix.co.uk> 2003
   Licence:  GNU Public Licence v.2 or later

 */

#define _GNU_SOURCE

/* size of allocated arrays */
#define BUFSIZ  127
#define PATHLEN 1024
#define LINELEN 1024

/* error codes */
#define LOC_ERR_PROG_FAILED  255
#define LOC_ERR_SYNTAX       254
#define LOC_ERR_SYSTEM       253
#define LOC_ERR_BAD_HOST     252
#define LOC_ERR_READ_FAIL    251
#define LOC_ERR_WRITE_FAIL   250
#define LOC_ERR_CONFIG       249
#define LOC_ERR_FILE_FORMAT  248
#define LOC_ERR_PERM	     247

#define DO_OVERWRITE         1
#define DO_NOT_OVERWRITE     0

#define SET_CLUSTER          1
#define SET_DATABASE         2

/* Declarations */
void   find_settings(char *path);
void   add_version_to_path(char *path);

char  *find_host (const int cnt,  char **args, const int ix);
void   exec_program (int argc, char** argv);
void   set_defaults (void);
void   write_cluster_line(const char * user, const char * group,
			  const char * cluster, const char *db,
			  const int forceflag);
void   write_rc(const char *clustername, const char *dbname);
void   get_sys_default_info(int *type, char *name,
			    char *cluster, char *database, int *frc);

void   get_user_default_info(char *cluster, char * database);
int    valid_cluster(const char *cluster);
