#!/bin/bash

# variables
################################################################################
TMPDIR=`mktemp -d`
TMPONE=$TMPDIR/one.tmp
ALLREPOSLIST=$TMPDIR/repo_directories.txt
RUNNINGLIST=$TMPDIR/running_jobs.txt
DELETELIST=$TMPDIR/delete_list.txt

# functions
################################################################################

# help
########################################
f_help () {
  echo "
This script clears up disk space on executors by deleting unnecessary files.

OPTIONS:
  -h, --help        View this help file.
  -dr, --dry-run    Safely run script without changing anything.
  -gr, --git-repos  Delete cached git repos.

$MSG
" ;exit ; }

# error
########################################
f_err () { MSG="!!! ERROR !!! $1" ;f_help ; }

# dry run
########################################
f_dry () {
  if [[ $DRYRUN == 'true' ]] ;then echo "Dry Run: $1"
  else echo "Live Run: $1" ;eval "$1" ;fi ; }

# clear cached git repos:
#   /domino/<Executor>/executor/replicatorStorage/prepared/<RunID>
########################################
f_git_repos () {

# error check
FINDPATH='/domino/*/executor/replicatorStorage'
FINDDIR='prepared'
if [[ ! -d `find $FINDPATH -mindepth 1 -maxdepth 1 -type d -name $FINDDIR |head -1` ]] ;then
  f_err "Directory not found: $FINDPATH/$FINDDIR" ;fi

# make a list of all cached git repos
find $FINDPATH/$FINDDIR -mindepth 1 -maxdepth 1 -type d > $ALLREPOSLIST

# make a list of all running jobs
docker ps |awk -F'domino-run-' '{print $2}' |column -t |sort > $RUNNINGLIST

# make initial delete list from cached git repos
cp -f $ALLREPOSLIST $DELETELIST

# remove running jobs from the delete list
for runid in `cat $RUNNINGLIST` ;do
  grep -v $runid $DELETELIST > $TMPONE  # grep out runid
  cp -f $TMPONE $DELETELIST ;done  # reset delete list

# capture disk space: before
DISKB=`df -h |grep 'domino' |grep -v 'domino/' |column -t`

# delete remaining, unused git repos
for repo in `cat $DELETELIST` ;do
  if [[ -d $repo ]] && [[ `echo $repo |grep "$FINDDIR"` ]] ;then
    echo "Validated string and directory... deleting file: $repo"
    f_dry "rm -rf $repo"
  else
    echo "Unvalidated string and/or a directory... skipping file: $repo"
  fi
done

# capture disk space: after
DISKA=`df -h |grep 'domino' |grep -v 'domino/' |column -t`

# output
echo "
--- current running jobs:
`docker ps`

--- leftover cached git repos (tail'd):
`find $FINDPATH/$FINDDIR -mindepth 1 -maxdepth 1 -type d |tail`

--- total repos:          `cat $ALLREPOSLIST |wc -l`
--- total running jobs:   `cat $RUNNINGLIST |wc -l`
--- total repos removed:  `cat $DELETELIST |wc -l`
--- disk before:          `echo $DISKB`
--- disk after:           `echo $DISKA`
"

# cleanup
if [[ -d $TMPDIR ]] && [[ `ls -ald $TMPDIR |grep tmp` ]] ;then rm -rf $TMPDIR ;fi
}

# script start
################################################################################

# process arguments
########################################
while (( "$#" > 0 )) ;do
  case $1 in
    '-h'|'--help')  f_help  ;;
    '-dr'|'--dry-run')  DRYRUN=true ;shift ;;
    '-gr'|'--git-repos')  GITREPO=true ;EXEC=true ;shift ;;
    *)  f_err "Invalid argument: $1"  ;;
  esac
done

# error checks
########################################

# check if root
if [[ `whoami` != 'root' ]] ;then f_err "This script needs to be executed as the 'root' user." ;fi

# execute
########################################

if [[ $EXEC == 'true' ]] ;then
  if [[ $GITREPO == 'true' ]] ;then f_git_repos ;fi
else f_help ;fi

