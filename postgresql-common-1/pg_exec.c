#/*
   pg_exec.c
  
   Run programs for pg_wrapper.
  
   Copyright (c) Oliver Elphick <olly@lfix.co.uk> 2003
   Licence:  GNU Public Licence v.2 or later

 */

#define _GNU_SOURCE

#include "pg_wrapper.h"
#include "pg_vars.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/utsname.h>

extern int h_errno;

int  remote_host(const char *host);


/********************************************************************
 For pg_exec and linked names: run the command 
 ********************************************************************/
void exec_program (int argc, char **argv) {
  char path[PATHLEN+1] = "/usr/lib/postgresql/";
  char msg[PATHLEN + PATHLEN];

  if (! remote_host(hostname)) {
    find_settings(path);
  } else {
    add_version_to_path(path);

    setenv("PGHOST", hostname, DO_OVERWRITE);
  }
  strncat(path, progname, PATHLEN - strlen(path));
  path[PATHLEN] = '\0';
  *argv = path;

  /* run the command */
  execve(path, argv, environ);
  /* Only get here if the command failed */
  snprintf(msg, PATHLEN + PATHLEN, "Command %s failed", path);
  perror(msg);
  exit (LOC_ERR_PROG_FAILED);
} /* exec_program() */


/********************************************************************
 Check whether the specified host is remote or not;
   returns 1 if remote, 0 if local
 ********************************************************************/
int remote_host(const char* host) {
  struct hostent   *hptr, *rptr;
  struct utsname   myname;
  struct in_addr   addr;
  struct in6_addr  addr6;
  char             **pptr;

  if (host[0] == '/' || host[0] == '\0')  /* UNIX socket */
    return 0;

  /* is it dotted quad IPv4 notation? */
  if (inet_pton(AF_INET, host, &addr) == 0) {
#ifdef AF_INET6
    /* is it IPv6? */
    if (inet_pton(AF_INET6, host, &addr6) == 0) {
#endif /* AF_INET6 */ 
      /* no, so translate the name to a hostent structure */
      if (!(rptr = gethostbyname(host)))  {
	fprintf(stderr, "Invalid hostname %s\n", host);
	exit(LOC_ERR_BAD_HOST);
      }
#ifdef AF_INET6
    } else {
      /* valid IPv6 address - produce a hostent structure */
      rptr = gethostbyaddr((const char *) &addr6, 16, AF_INET6);
    }
#endif /* AF_INET6 */
  } else {
    /* valid IPv4 address - produce a hostent structure */
    rptr = gethostbyaddr((const char *) &addr, 4, AF_INET);
  }

  /* now compare the requested address with the local ones */
  if (uname(&myname) < 0) {
    perror("Cannot determine local hostname");
    exit(LOC_ERR_SYSTEM);
  }
  if ( (hptr = gethostbyname2(myname.nodename, rptr->h_addrtype)) == NULL) {
    perror ("Cannot determine local network interface addresses");
    exit (LOC_ERR_SYSTEM);
  }

  switch (hptr->h_addrtype) {
  case AF_INET:
#ifdef AF_INET6
  case AF_INET6:
#endif /* AF_INET6 */
    pptr = hptr->h_addr_list;
    for ( ; *pptr != NULL; pptr++) {
      if ( ! memcmp(*pptr, rptr->h_addr, hptr->h_length) )
	return(0);  /* this is a local address */
    }
    break;
  default:
    fprintf(stderr, "Unknown address type %d\n", hptr->h_addrtype);
    exit(LOC_ERR_SYSTEM);
    break;
  }

  return(1);  /* this is a remote address */

} /* remote_host() */




/********************************************************************
 Find the selected host in the command line options, or failing that,
   in the environment.

   Do not allow the hostname to be specified in the command line options if
   it has already been specified differently in the pg_exec options.
 
 ********************************************************************/
char *find_host(int cnt, char **args, int ix) {
  char **ptr;
  static char result[BUFSIZ];

  result[0] = '\0';
  /* go backwards through the options to find the last -h or --host */
  for (ptr = &(args[cnt - 1]); (ptr - args) >= ix; ptr--) {
    if (! strncmp(*ptr, "-h", 2)) {
      char *wptr = *ptr;
      
      /* get the hostname if specified by -hhostname */
      wptr += 2;
      strncpy(result, wptr, BUFSIZ);
      if (result[0] == '\0') {
	/* now try -h hostname or --host hostname */
	strncpy(result, *(ptr + 1), BUFSIZ);
      }
    }
    if (result[0] != '\0')
      break;

    if (! strcmp(*ptr, "--host")) {
      strncpy(result, *(ptr + 1), BUFSIZ);
    }

    if (result[0] != '\0')
      break;
  }

  /* abort if the hostname has been specified twice */
  if (result[0] != '\0' && hostname[0] != '\0' && strcmp(result, hostname)) {
    fprintf(stderr, "Different hosts specified in command options and pg_exec options.\nError abort.");
    exit(LOC_ERR_SYNTAX);
  }

  if (hostname[0] == '\0' && result[0] == '\0' && getenv("PGHOST") != NULL) {
    /* Read PGHOST from the environment */
    strncpy(result, getenv("PGHOST"), BUFSIZ);
  }

  return(result);
}  /* find_host() */


