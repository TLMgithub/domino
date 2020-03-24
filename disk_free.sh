#!/bin/bash

# variables
################################################################################
TMPDIR=`mktemp -d`
TMPONE=$TMPDIR/one.tmp
REPOLIST=$TMPDIR/repo.txt
JOBLIST=$TMPDIR/jobs.txt
PRUNELIST=$TMPDIR/pruned_repo.txt

# functions
################################################################################

# help
########################################
f_help () {
  echo "
This script clears up disk space on executors by deleting unnecessary files.

OPTIONS:
  -h, --help      View this help file.
  -dr, --dry-run  Safely run script without changing anything.

$MSG
"
exit
}

# error
########################################
f_err () {
  MSG="ERROR!: $1" ;f_help
}

# clear cached git repos:
#   /domino/<Executor>/executor/replicatorStorage/prepared/<RunID>
########################################
f_git_repos () {

# make list of all cached git repos
find /domino/*/executor/replicatorStorage/prepared/ -mindepth 1 -maxdepth 1 -type d > $REPOLIST

# make list of all running jobs
docker ps |awk -F'domino-run-' '{print $2}' |column -t |sort > $JOBLIST

# filter out running jobs from cached git repo list
cp -f $REPOLIST $PRUNELIST
for runid in `cat $JOBLIST` ;do
  grep -v $runid $PRUNELIST > $TMPONE
  cp -f $TMPONE $PRUNELIST
done

# capture disk space: before
DISKB=`df -h |grep 'domino' |grep -v 'domino/' |column -t`

# delete remaining, unused cached git repos
for runid in `cat $PRUNELIST` ;do
  if [[ `echo $runid |grep 'replicatorStorage'` ]] && [[ -d $runid ]] ;then
    echo "Validated string and directory... proceeding to delete $runid"
    rm -rf $runid
  else
    echo "Unvalidated string and/or a directory... skipping $runid"
  fi
done

# capture disk space: after
DISKA=`df -h |grep 'domino' |grep -v 'domino/' |column -t`

# output
clear
echo "
>> current running jobs:

`docker ps`

>> leftover cached git repos:

`find /domino/*/executor/replicatorStorage/prepared/ -mindepth 1 -maxdepth 1 -type d |tail`

>> total repos:          `cat $REPOLIST |wc -l`
>> total running jobs:   `cat $JOBLIST |wc -l`
>> total repos removed:  `cat $PRUNELIST |wc -l`
>> disk before:          `echo $DISKB`
>> disk after:           `echo $DISKA`
"

# cleanup
rm -f $TMPONE
}

# script start
################################################################################

# process options
########################################
while (( "$#" > 0 )) ;do
  case $1 in
    ''|'-h'|'--help')  f_help ;exit  ;;
    '-dr'|'--dry-run')  DRYRUN=true ;shift ;;
    '-gr'|'--git-repos')  GITREPO=true ;shift ;;
    *)  f_err "Invalid arguments: $@"  ;;
  esac
done

# error checks
########################################

# check if root
if [[ $whoami != 'root' ]] ;then
  echo "Error: This script needs to be executed as the 'root' user."
fi

# execute
########################################
exit

if [[ $GITREPO == 'true' ]] ;then
  f_git_repos ;fi

