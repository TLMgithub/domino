#!/bin/bash

# variables
################################################################################
SEDFILE='/tmp/dispatcher.sed'  # sed lines for reporting
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
  
  \`sed\` file: $SEDFILE
  This is for reporting only.
  Should contain any \`sed\` commands you'd like to run against the
    report output: $REPFILE
  Format Example:
    <ValueToOmit>/d
    s/<ValueBefore>/<ValueAfter>/g
    ...

OPTIONS:
  -h, --help           display this help text
  -k, --keep           don't delete output file
  -t, --tier           sort runs by tier
  -e, --executor       sort runs by executor
  -c, --cpu            sort runs by cpu usage
  -m, --mem            sort runs by memory usage
  -u, --user           sort runs by user
  -p, --project        sort runs by project name
  -d, --date           sort runs by start date (converts date format: `date +%F`)
  -r, --report         create report file (converts date format: `date +%F`)
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

# reformat and sort
########################################
f_sort () {

  # cut off top section
  echo "Removing unnecessary sections..."
  CATN=`cat -n $DISRAW |grep 'Currently Executing Runs' |head -n1 |awk '{print $1}'`
  tail -n +$CATN $DISRAW |tail -n +2 > $TMPONE

  # cut off bottom section
  CATN=`cat -n $TMPONE |grep 'Run Queue' |head -n1 |awk '{print $1}'`
  head -n$CATN $TMPONE |head -n -1 > $DISOUT

  # extract relevant fields: generic
  echo "Extracting generic fields (1/4)..."
  cat $DISOUT |awk '{print $3, $2, $6, $5}' > $TMPONE

  # extract relevant fields: date
  echo "Extracting date fields (2/4)..."
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

  # extract relevant fields: time and resource usage
  echo "Extracting time and resource usage fields (3/4)..."
  cat $DISOUT |awk -F'@' '{print $2}' |awk '{print $1, $2, $3, $4, $5, $6, $7}' |sed 's/m -- --/m - - - -/g' |awk '{print $1$2, $3$4, $5$6, $7}' > $TMPTHREE

  # extract relevant fields: Run ID
  echo "Extracting RunIDs (4/4)..."
  cat $DISOUT |awk '{print $1}' > $TMPFOUR

  # consolidate fields
  cat /dev/null > $DISOUT
  COUNT='1'
  MAXCOUNT=`cat $TMPONE |wc -l`
  for line in `cat -n $TMPONE |awk '{print $1}'` ;do
    echo "Consolidating field $COUNT/$MAXCOUNT..."
    echo "`sed -n $line\p $TMPONE` `sed -n $line\p $TMPTWO` `sed -n $line\p $TMPTHREE` `sed -n $line\p $TMPFOUR`" >> $DISOUT
    COUNT=$((COUNT+1))
  done

  # process `sed` values
  echo "Processing \`sed\` values..."
  for line in `cat $SEDFILE` ;do
    echo "Processing: $line..."
    sed -i "$line" $DISOUT ;done

  # insert header label
  echo "HARDWARE EXECUTOR USER PROJECT DATE TIME CPU MEM STATE RUN_ID" >> $DISOUT

  # add sort columns
  awk -v columnone=$1 -v columntwo=$2 -v columnthree=$3 '{print $columnone, $columntwo, $columnthree, $0}' $DISOUT > $TMPTWO

  # sort
  #sort -n $TMPTWO |awk '{$1=$2=$3="" ;print $0}' |column -t > $TMPONE
  vim -c ':sort' -c ':wq' $TMPTWO ;awk '{$1=$2=$3="" ;print $0}' $TMPTWO |column -t > $TMPONE

  # move header label and add numbering
  echo "0 `grep ^HARDWARE $TMPONE`" > $TMPTHREE
  grep -v ^HARDWARE $TMPONE > $TMPTWO
  cat -n $TMPTWO >> $TMPTHREE

  # additional reporting processes
  if [[ $REP = 'true' ]] ;then

    # additional reporting process: remove unnecessary columns
    mv $TMPTHREE $TMPONE
    awk '{$3=$10="" ;print $0}' $TMPONE > $TMPTHREE

    # create report file
    column -t $TMPTHREE > $DISOUT
    cp -af $DISOUT $REPFILE ;echo "Report File: $REPFILE"
  else

    # clean up output
    column -t $TMPTHREE > $DISOUT ;fi

  # view output
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
if [[ -z $DISRAW ]] ;then f_err "File is empty: $DISRAW" ;fi

# check reference file
if [[ ! -f $SEDFILE ]] ;then f_err "File does not exist: $SEDFILE" ;fi
if [[ -z $SEDFILE ]] ;then f_err "File is empty: $SEDFILE" ;fi

# process flags
########################################
if [[ $TIER == 'true' ]] ;then f_sort 1 2 3
elif [[ $EXEC == 'true' ]] ;then f_sort 2 3 4
elif [[ $CPU == 'true' ]] ;then f_sort 7 8 3
elif [[ $MEM == 'true' ]] ;then f_sort 8 7 3
elif [[ $USER == 'true' ]] ;then f_sort 3 4 2
elif [[ $PROJ == 'true' ]] ;then f_sort 4 3 2
elif [[ $DATE == 'true' ]] ;then f_sort 5 6 3
elif [[ $REP == 'true' ]] ;then f_sort 1 3 4 ;fi

# filter options
########################################

# cleanup
########################################
rm -f $TMPONE $TMPTWO $TMPTHREE $TMPFOUR
if [[ $KEEP == 'true' ]] ;then
  echo "Output File = $DISOUT"
else
  rm -f $DISOUT
fi

