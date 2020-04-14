#!/bin/bash

# variables
################################################################################
DISRAW='/tmp/dispatcher.txt'  # dispatcher raw data/input
DISOUT=`mktemp`  # output from this script
TMPONE=`mktemp`
TMPTWO=`mktemp`
TMPTHREE=`mktemp`

# help text
########################################
HELPTXT="
This script parses data from raw dispatcher ouput, which should be here:
$DISRAW

OPTIONS:
  -h, --help      display this help text
  -t, --tier      find current runs by tier
  -e, --executor  find current runs by executor
  -c, --cpu       find current runs by cpu usage
  -m, --mem       find current runs by memory usage
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

# precheck
########################################
f_precheck () {
if [[ ! -f $DISRAW ]] ;then
  echo "error: $DISRAW does not exist" ;exit
elif [[ -z $DISRAW ]] ;then
  echo "error: $DISRAW is empty" ;exit
fi
}

# cut out "Currently Executing Runs"
########################################
f_reformat () {

  # cut off top section
  CATN=`cat -n $DISRAW |grep 'Currently Executing Runs' |head -n1 |awk '{print $1}'`
  tail -n +$CATN $DISRAW |tail -n +2 > $TMPONE

  # cut off bottom section
  CATN=`cat -n $TMPONE |grep 'Run Queue' |head -n1 |awk '{print $1}'`
  head -n$CATN $TMPONE |head -n -1 > $DISOUT

  # reformat output
  cat $DISOUT |awk '{print $3, $2, $6, $5, $1}' > $TMPONE
  cat $DISOUT |awk -F'@' '{print $2}' |awk '{print $3, $4, $5, $6, $7}' > $TMPTWO
  cat /dev/null > $DISOUT
  for CNT in `cat -n $TMPONE |awk '{print $1}'` ;do
    echo "`sed -n $CNT\p $TMPONE` `sed -n $CNT\p $TMPTWO`" >> $DISOUT
  done
}

# sort current runs by tier
########################################
f_tier () {
  f_precheck ;f_reformat
  sort -n $DISOUT > $TMPONE
  column -t $TMPONE > $DISOUT
  less $DISOUT
}

# sort current runs by executor
########################################
f_executor () {
  f_precheck ;f_reformat
  awk '{print $2, $0}' $DISOUT |sort -n > $TMPONE
  awk '{$1="" ;print $0}' $TMPONE |column -t > $DISOUT
  less $DISOUT
}

# sort current runs by cpu usage
########################################
f_cpu () {
  f_precheck ;f_reformat
  awk '{print $6, $0}' $DISOUT |sort -n > $TMPONE
  awk '{$1="" ;print $0}' $TMPONE |column -t > $DISOUT
  less $DISOUT
}

# sort current runs by mem usage
########################################
f_mem () {
  f_precheck ;f_reformat
  awk '{print $8, $0}' $DISOUT |sort -n > $TMPONE
  awk '{$1="" ;print $0}' $TMPONE |column -t > $DISOUT
  less $DISOUT
}

# script start
################################################################################

# set flags
########################################
if [[ "$#" == 0 ]] ;then f_help ;fi  # if no arguments, display the help text
while (( "$#" > 0 )) ;do
  case $1 in
    '-h'|'--help')  f_help  ;;
    '-t'|'--tier')  TIER='true' ;shift ;;
    '-e'|'--executor')  EXEC='true' ;shift ;;
    '-c'|'--cpu')  CPU='true' ;shift ;;
    '-m'|'--mem')  MEM='true' ;shift ;;
    *)  f_err "Invalid argument: $1"  ;;
  esac
done

# error checks
########################################

# check dispatcher file
if [[ ! -f $DISRAW ]] ;then f_err "File does not exist: $DISRAW" ;fi

# process flags
########################################

if [[ $TIER == 'true' ]] ;then
  f_tier
elif [[ $EXEC == 'true' ]] ;then
  f_executor
elif [[ $CPU == 'true' ]] ;then
  f_cpu
elif [[ $MEM == 'true' ]] ;then
  f_mem
fi

# filter options
########################################

# cleanup
########################################
rm -f $TMPONE $TMPTWO $TMPTHREE $DISOUT

