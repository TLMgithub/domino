#!/bin/bash

# variables
################################################################################
HELPTXT="
This script clears up disk space on executors by deleting unnecessary files.

OPTIONS:
  -h, --help           View this help file.
  -dr, --dry-run       Safely run script without changing anything.
  -cr, --cached-repos
    Delete cached git repos:
      /domino/<Executor>/executor/replicatorStorage/prepared/<RunID>/

"

# library
################################################################################

# help
########################################
f_help () { echo "$HELPTXT" ;echo "$MSG" ;echo ;exit ; }

# error
########################################
f_err () { MSG="!!! ERROR !!! $1" ;f_help ; }

# dry run
########################################
f_dry () {
  if [[ $DRYRUN == 'true' ]] ;then echo "Dry Run: $1"
  else echo "Live Run: $1" ;eval "$1" ;fi ; }

# error check: root exec
########################################
f_root () {
if [[ `whoami` != 'root' ]] ;then
  f_err "This script needs to be executed as the 'root' user." ;fi ; }

# functions
################################################################################

# prune "delete" list
f_prune () {
for string in `echo "$PRUNELIST"` ;do  # iterate through list
  TMPONE="`echo \"$DELETELIST\" |grep -v \"$string\"`"  # grep out string
  DELETELIST="$TMPONE" ;done ; } # reset delete list

# delete files
########################################
f_delete_files () {

### error checks

# path exists
FULLPATH="`find $FINDPATH -mindepth 1 -maxdepth 1 -type d -name $FINDDIR`"
if [[ ! -d $FULLPATH ]] ;then
  f_err "Directory not found: $FULLPATH" ;fi

# single directory
DIRCOUNT=`echo "$FULLPATH" |wc -l`
if [[ $DIRCOUNT > 1 ]] ;then
  f_err "Too many Directories: $DIRCOUNT" ;fi

### make lists

# all files to be deleted
ALLFILESLIST="`find $FULLPATH -mindepth 1 -maxdepth 1 -type d`"

# initial delete list from "all files" list
DELETELIST="$ALLFILESLIST"

# all run IDs for current jobs
RUNIDSLIST="`docker ps |awk -F'domino-run-' '{print $2}' |column -t |sort`"

### prune "delete" list

# exempt current run IDs
PRUNELIST="$RUNIDSLIST" ;f_prune

# remove any special file exceptions
PRUNELIST="$EXCEPTLIST" ;f_prune

### delete files

# capture disk space: before deletion
DISKB="`df -h |grep ^/dev |column -t`"

# delete files using the pruned "delete" list
for file in `echo "$DELETELIST"` ;do
  if [[ -d $file ]] && [[ `echo $file |grep "$FINDDIR"` ]] ;then
    echo "Validated file type and string... deleting file: $file"
    f_dry "rm -rf $file"
  else
    echo "Unvalidated file type and/or string... skipping file: $file"
  fi
done

# capture disk space: after deletion
DISKA="`df -h |grep ^/dev |column -t`"

### output

echo "
--- current running jobs:
`docker ps`

--- remaining files (tail'd):
`find $FULLPATH -mindepth 1 -maxdepth 1 -type d |tail`

--- disk before:
$DISKB

--- disk after:
$DISKA

--- file total:     `echo "$ALLFILESLIST" |wc -l`
--- running jobs:   `echo "$RUNIDSLIST" |wc -l`
--- files removed:  `echo "$DELETELIST" |wc -l`
"
}

# script start
################################################################################

# process arguments
########################################
EXEC=false
while (( "$#" > 0 )) ;do
  case $1 in
    '-h'|'--help')  f_help  ;;
    '-dr'|'--dry-run')  DRYRUN='true' ;shift ;;
    '-cr'|'--cached-repos')  CACHEDREPO='true' ;EXEC='true' ;shift ;;
    *)  f_err "Invalid argument: $1"  ;;
  esac
done

# error checks
########################################

# check if root
f_root

# check docker
if [[ ! `which docker` ]] ;then f_err "Command not found: docker" ;fi

# process flags
########################################

if [[ $EXEC == 'true' ]] ;then
  EXCEPTLIST=''
  if [[ $CACHEDREPO == 'true' ]] ;then
    FINDPATH='/domino/*/executor/replicatorStorage'
    FINDDIR='prepared'
    EXCEPTLIST=""
    f_delete_files ;fi
else f_help ;fi

