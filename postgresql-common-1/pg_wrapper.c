#/*
   pg_wrapper.c
  
   Handle clusters of PostgreSQL databases with different versions
   installed simultaneously.
  
   Copyright (c) Oliver Elphick <olly@lfix.co.uk> 2003
   Licence:  GNU Public Licence v.2 or later

   This program operates differently depending on how it is called:
   pg_default   -   set defaults for invoking PostgreSQL programs
   pg_exec      -   run the correct version of a PostgreSQL program
   pg_wrapper   -   [not allowed]
   {program}    -   runs the correct version of {program}

 */

#include "pg_wrapper.h"

#include <string.h>
#include <stdio.h>
#include <getopt.h>
#include <stdlib.h>


extern int h_errno;
extern char *optarg;
extern int optind, opterr, optopt;


void syntax (const char *prog);

 char *progname;
 char *username;
 char *groupname;
 char *clustername;
 char *dbname;
 char *hostname;
 char *version;
 int set_default, force, release;
 int port;
 int verbose;

/**********************************************************************
 Syntax help message
 **********************************************************************/
void syntax(const char *prog) {
  int x = 1;
  printf("Syntax:\n  ");

  if (! strcmp("pg_default", prog)) {
    printf("pg_default -a | -u {user} | -g {group} [[-f|-r] -c {cluster} [-d {database}]]\n  "
	   "pg_default [-c {cluster} [-d {database}]\n");

  } else if (! strcmp("pg_exec", prog)) {
    printf("pg_exec [-v {version}][-h {remotehost}] {command} [{command options}]\n  "
	   "pg_exec [-v {version}] -c {cluster} pg_dump | pg_dumpall [{command options}]\n");

  } else if (! strcmp("pg_wrapper", prog)) {
    printf("pg_wrapper should not be called directly but should be linked to some\n"
	   " PostgreSQL program\n  for which it calls the version appropriate to\n"
	   " the current cluster.\n\n");

  } else {
    fprintf(stderr, "pg_wrapper called with unknown name\n"
	    "Call it as pg_exec, pg_default or a symlink to the name of a PostgreSQL program\n");
    x = 0;
  }

  if (x)
    printf("  %s -H    shows this help message\n", prog);
}  /* syntax() */


/*********************************************************************
 main 
 *********************************************************************/
int main(int argc, char **argv) {
  int c;
  char optlist[BUFSIZ+1];
  char called_as[BUFSIZ+1];
  char *ptr;
  
/* initialise global variables
 * these will be filled with at most BUFSIZ chars, so leave a guaranteed 0
 * terminator */
  progname = calloc(BUFSIZ+1, sizeof(char));
  username = calloc(BUFSIZ+1, sizeof(char));
  groupname = calloc(BUFSIZ+1, sizeof(char));
  clustername = calloc(BUFSIZ+1, sizeof(char));
  dbname = calloc(BUFSIZ+1, sizeof(char));
  hostname = calloc(BUFSIZ+1, sizeof(char));
  version = calloc(BUFSIZ+1, sizeof(char));
  
  set_default = 0;
  force = 0;
  release = 0;
  port = 5432;
  verbose = 0;
  
  /* strip off the path */
  if ( ! (ptr = strrchr(argv[0], '/')) )  {
    ptr = argv[0];
  } else {
    ptr++;
  }
  strncpy(called_as, ptr, BUFSIZ);

  /* initial command validation */
  if (! strcmp("pg_wrapper", called_as)) {
    /* pg_wrapper must not be run directly */
    syntax(called_as);
    exit(LOC_ERR_SYNTAX);

  } else if (! strcmp("pg_exec", called_as)) {
    /* This getopt pattern stops at the first non-option, so as to preserve the
       command and its options for pg_exec */  
    strncpy(optlist, "+c:h:v:H", BUFSIZ);

  } else if (! strcmp("pg_default", called_as)) {
    strncpy(optlist, "ac:d:fg:ru:HV", BUFSIZ);

  } else {
    /* a linked program: find the appropriate version and run the linked
       program */
    strncpy(progname, called_as, BUFSIZ);
    if (argc > 1)
      strncpy(hostname, find_host(argc, argv, 1), BUFSIZ);

    exec_program(argc, argv);
    exit(LOC_ERR_PROG_FAILED);  /* could not exec program */
  }

  /* process the command line options */
  while ((c = getopt (argc, argv, optlist)) != -1) {
    switch (c) {
    case 'a':
      set_default = 1;
      break;
    case 'c':
      strncpy(clustername, optarg, BUFSIZ);
      break;
    case 'd':
      strncpy(dbname, optarg, BUFSIZ);
      break;
    case 'f':
      force = 1;
      if (release) {
	fprintf(stderr, "%s error: -f and -r specified together\n", called_as);
	syntax(called_as);
	exit(LOC_ERR_SYNTAX);
      }
      break;
    case 'g':
      strncpy(groupname, optarg, BUFSIZ);
      break;
    case 'h':
      strncpy(hostname, optarg, BUFSIZ);
      break;
    case 'r':
      release = 1;
      if (force) {
	fprintf(stderr, "%s error: -f and -r specified together\n", called_as);
	syntax(called_as);
	exit(LOC_ERR_SYNTAX);
      }
      release = 1;
      break;
    case 'u':
      strncpy(username, optarg, BUFSIZ);
      break;
    case 'V':
      verbose = 1;
      break;
    case 'v':
      strncpy(version, optarg, BUFSIZ);
      break;
    case 'H':
      syntax(called_as);
      return(0);
      break;
    case '?':
      fprintf(stderr, "%s: unknown option -%c\n", called_as, optopt);
      syntax(called_as);
      exit(LOC_ERR_SYNTAX);
    default:
      /* should not happen */
      fprintf(stderr, "%s internal error: option -%c not handled\n",
	      called_as, c);
      syntax(called_as);
      exit(LOC_ERR_SYNTAX);
    }
  }
  
  if (! strcmp(called_as, "pg_exec")) {
    /* pg_exec */
    if (optind < argc)
      strncpy(progname, argv[optind], BUFSIZ);
    else
      progname[0] = '\0';

    if (progname[0] == '\0') {
      fprintf(stderr, "%s error: no program specified\n", called_as);
      exit(LOC_ERR_SYNTAX);
    }
    
    if ((ptr = find_host(argc, argv, optind))[0] != '\0')
      strncpy(hostname, ptr, BUFSIZ);

    exec_program(argc - optind, argv + optind);
  } else {
    /* pg_default */
    set_defaults();
  }
  
  return(0);
}  /* main() */

