#!/bin/bash

# variables
################################################################################
REFERENCE='/tmp/dispatcher.ref'  # reference file for this script
DISRAW='/tmp/dispatcher.txt'  # dispatcher raw data/input
REPFILE="./domino_capacity_report.`date +%F`.txt"
DISOUT=`mktemp`  # output from this script
TMPONE=`mktemp`
TMPTWO=`mktemp`
TMPTHREE=`mktemp`
TMPFOUR=`mktemp`

# help text
########################################
HELPTXT="
This script parses data from raw dispatcher ouput.

SOURCED FILES:
  Dispatcher file: $DISRAW
  Copy and paste dispatcher plain text into this file.
  
  Reference file: $REFERENCE
  Create a variable called \"SEDVALS\".
    This is for reporting only.
    This variable should contain any \`sed\` commands you'd like to run against
      the raw output: $REPFILE
    Format Example:
      SEDVALS='s/<ValueBefore1>/<ValueAfter1>/g
      s/<ValueBefore>/<ValueAfter>/g
      ...'

OPTIONS:
  -h, --help      display this help text
  -k, --keep      don't delete output file
  -t, --tier      find current runs by tier
  -e, --executor  find current runs by executor
  -c, --cpu       find current runs by cpu usage
  -m, --mem       find current runs by memory usage
  -u, --user      find current runs by user
  -p, --project   find current runs by project name
  -d, --date      find current runs by start date
  -r, --report    create report file for userbase
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
echo "Executing Pre-check..."
if [[ ! -f $DISRAW ]] ;then
  echo "error: $DISRAW does not exist" ;exit
elif [[ -z $DISRAW ]] ;then
  echo "error: $DISRAW is empty" ;exit
fi
}

# cut out "Currently Executing Runs" section
########################################
f_reformat () {

  # cut off top section
  echo "Removing unnecessary sections..."
  CATN=`cat -n $DISRAW |grep 'Currently Executing Runs' |head -n1 |awk '{print $1}'`
  tail -n +$CATN $DISRAW |tail -n +2 > $TMPONE

  # cut off bottom section
  CATN=`cat -n $TMPONE |grep 'Run Queue' |head -n1 |awk '{print $1}'`
  head -n$CATN $TMPONE |head -n -1 > $DISOUT

  # extract relevant fields (1/3): generic
  echo "Extracting generic fields (1/3)..."
  cat $DISOUT |awk '{print $3, $2, $6, $5, $1}' > $TMPONE
  
  # extract relevant fields (2/3): date
  echo "Extracting date fields (2/3)..."
  if [[ $DATE == 'true' ]] ;then
    cat $DISOUT |awk -F'@' '{print $1}' |awk '{print $NF, $(NF-2), $(NF-1)}' > $TMPTWO
    sed -i 's/,//g' $TMPTWO
    sed -i 's/ /-/g' $TMPTWO
    sed -i 's/Jan/01/g' $TMPTWO
    sed -i 's/Feb/02/g' $TMPTWO
    sed -i 's/Mar/03/g' $TMPTWO
    sed -i 's/Apr/04/g' $TMPTWO
    sed -i 's/May/05/g' $TMPTWO
    sed -i 's/Jun/06/g' $TMPTWO
    sed -i 's/Jul/07/g' $TMPTWO
    sed -i 's/Aug/08/g' $TMPTWO
    sed -i 's/Sep/09/g' $TMPTWO
    sed -i 's/Oct/10/g' $TMPTWO
    sed -i 's/Nov/11/g' $TMPTWO
    sed -i 's/Dec/12/g' $TMPTWO
  else
    cat $DISOUT |awk -F'@' '{print $1}' |awk '{print $(NF-2), $(NF-1), $NF}' > $TMPTWO
  fi

  # extract relevant fields (3/3): time and resource usage
  echo "Extracting time and resource usage fields (3/3)..."
  cat $DISOUT |awk -F'@' '{print $2}' |awk '{print $1, $2, $3, $4, $5, $6, $7}' |sed 's/m -- --/m - - - -/g' |awk '{print $1, $2, $3, $4" cpu "$5, $6" mem "$7}' > $TMPTHREE

  # consolidate fields
  cat /dev/null > $DISOUT
  COUNT='1'
  MAXCOUNT=`cat $TMPONE |wc -l`
  for line in `cat -n $TMPONE |awk '{print $1}'` ;do
    echo "Consolidating field $COUNT/$MAXCOUNT..."
    echo "`sed -n $line\p $TMPONE` `sed -n $line\p $TMPTWO` `sed -n $line\p $TMPTHREE`" >> $DISOUT
    COUNT=$((COUNT+1))
  done

  # process `sed` values for reporting
  if [[ $REP = 'true' ]] ;then
    echo "Processing \`sed\` values for reporting..."
    for line in `echo "$SEDVALS"` ;do
      echo "Processing: $line..."
      sed -i "$line" $DISOUT ;done ;fi
}

# sort by column number
########################################
f_sort () {
  f_precheck ;f_reformat
  awk -v columnone=$1 -v columntwo=$2 -v columnthree=$3 '{print $columnone, $columntwo, $columnthree, $0}' $DISOUT |sort -n > $TMPONE
  awk '{$1=$2=$3="" ;print $0}' $TMPONE |cat -n |column -t > $DISOUT
}

# extra report processing
########################################
f_report () {

# check reference file
if [[ ! -f $REFERENCE ]] ;then f_err "File does not exist: $REFERENCE" ;fi

# remove unnecessary content
awk '{$3=$6="" ;print $0}' $DISOUT > $TMPONE

# remove production runIDs
cat $TMPONE |column -t > $DISOUT
}

# script start
################################################################################

# set flags
########################################
if [[ "$#" == 0 ]] ;then f_help ;fi  # if no arguments, display the help text
while (( "$#" > 0 )) ;do
  case $1 in
    '-h'|'--help')  f_help  ;;
    '-k'|'--keep')  KEEP='true' ;shift ;;
    '-t'|'--tier')  TIER='true' ;shift ;;
    '-e'|'--executor')  EXEC='true' ;shift ;;
    '-c'|'--cpu')  CPU='true' ;shift ;;
    '-m'|'--mem')  MEM='true' ;shift ;;
    '-u'|'--user')  USER='true' ;shift ;;
    '-p'|'--project')  PROJ='true' ;shift ;;
    '-d'|'--date')  DATE='true' ;shift ;;
    '-r'|'--report')  REP='true' ;shift ;;
    *)  f_err "Invalid argument: $1"  ;;
  esac
done

# error checks
########################################

# check dispatcher file
if [[ ! -f $DISRAW ]] ;then f_err "File does not exist: $DISRAW" ;fi

# process flags
########################################
source $REFERENCE

if [[ $TIER == 'true' ]] ;then
  f_sort 1 2 3 ;less $DISOUT
elif [[ $EXEC == 'true' ]] ;then
  f_sort 2 1 3 ;less $DISOUT
elif [[ $CPU == 'true' ]] ;then
  f_sort 11 13 3 ;less $DISOUT
elif [[ $MEM == 'true' ]] ;then
  f_sort 13 11 3 ;less $DISOUT
elif [[ $USER == 'true' ]] ;then
  f_sort 3 4 2 ;less $DISOUT
elif [[ $PROJ == 'true' ]] ;then
  f_sort 4 3 2 ;less $DISOUT
elif [[ $DATE == 'true' ]] ;then
  f_sort 6 7 8 ;less $DISOUT
elif [[ $REP == 'true' ]] ;then
  f_sort 1 3 4 ;f_report ;less $DISOUT
fi

# filter options
########################################

# cleanup
########################################
rm -f $TMPONE $TMPTWO $TMPTHREE
if [[ $KEEP == 'true' ]] ;then
  echo "Output File = $DISOUT"
else
  rm -f $DISOUT
fi

