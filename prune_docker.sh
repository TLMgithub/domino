#!/bin/sh

# functions
################################################################################

# help text
f_help () {
echo "
syntax:
	$0 {option}

options:
	-h	show this help text
	-r	run this script
	-dr	do a dry run of this script
"
}

# dry run
f_dryrun () {
if [[ $DRYRUN == 'true' ]] ;then
	echo "DRYRUN: $1" >> $LOGFILE
else
	echo "RUN: $1" >> $LOGFILE
	eval "$1"
fi
}

# remove non-essential docker contianers
f_containers () {

# set label for output and display message
LABEL='container_id  repository:tag'
echo '
PROCESSING DOCKER CONTAINERS...' >> $LOGFILE

# store a list of all containers in a variable and add to log file
TMPONE="`docker ps -a |sort |awk '{print $1, $2}' |sed '/^$/d' |column -t`"
ACTS="`echo \"$TMPONE\" |grep -v CONTAINER`"  # all containers
echo "
all containers: `echo \"$ACTS\" |wc -l`
$LABEL
$ACTS" >> $LOGFILE

# store a list of domino containers (essential) in a variable and add to log file
DCTS="`echo \"$ACTS\" |grep -i -e 'executor' -e 'fluent'`"  # domino containers
echo "
domino containers (essential): `echo \"$DCTS\" |wc -l`
$LABEL
$DCTS" >> $LOGFILE

# store a list of running containers (essential) in a variable and add to log file
TMPONE="`docker ps |sort |awk '{print $1, $2}' |sed '/^$/d' |column -t`"
RCTS="`echo \"$TMPONE\" |grep -v CONTAINER`"  # running containers
echo "
running containers (essential): `echo \"$RCTS\" |wc -l`
$LABEL
$RCTS" >> $LOGFILE

# store a list of essential containers in a variable and add to log file
TMPONE="`echo \"$DCTS\"`
`echo \"$RCTS\"`"
ECTS="`echo \"$TMPONE\" |sort |uniq`"  # essential containers
echo "
essential containers: `echo \"$ECTS\" |wc -l`
$LABEL
$ECTS" >> $LOGFILE

# store a list of non-essential/unused containers in a variable and add to log file
UCTS="$ACTS"  # initialize list with all containers
for ctid in `echo "$ECTS" |awk '{print $1}'` ;do  # iterate through essential container IDs
	TMPONE="`echo \"$UCTS\" |grep -v $ctid`"  # filter out essential containers
	UCTS="`echo \"$TMPONE\"`"  # unused containers
done
if [[ -z `echo "$UCTS"` ]] ;then
	FLAGONE='empty'
        echo "
non-essential containers: 0
$LABEL
(none)" >> $LOGFILE
else
        echo "
non-essential containers: `echo \"$UCTS\" |wc -l`
$LABEL
$UCTS" >> $LOGFILE
fi

# remove/delete non-essential/unused contianers and add to log file
echo "" >> $LOGFILE
if [[ $FLAGONE == 'empty' ]] ;then
	echo "No containers to remove.  Skipping..." >> $LOGFILE
else
	for ctid in `echo "$UCTS" |awk '{print $1}'` ;do
		echo "deleting CTID: $ctid" >> $LOGFILE
		f_dryrun "docker rm $ctid"
	done
fi
}

# remove unused docker images
f_images () {

# set label for output and display message
LABEL='image_id      repository:tag'
echo '
PROCESSING DOCKER IMAGES...' >> $LOGFILE

# store a list of all images in a variable and add to log file
TMPONE="`docker images |sort |awk '{print $3,$1":"$2}' |sed '/^$/d' |column -t`"
AIMG="`echo \"$TMPONE\" |grep -v REPOSITORY`"  # all images
echo "
all images: `echo \"$AIMG\" |wc -l`
$LABEL
$AIMG" >> $LOGFILE

# store a list of domino images (essential) in a variable and add to log file
DIMG="`echo \"$AIMG\" |grep -i -e 'executor' -e 'fluent'`"  # domino images
echo "
domino images (essential): `echo \"$DIMG\" |wc -l`
$LABEL
$DIMG" >> $LOGFILE

# store a list of currently used images (essential) in a variable and add to log file
RIMG=""
for image in `echo "$RCTS" |awk '{print $2}'` ;do
	TMPONE="$RIMG
`echo \"$AIMG\" |grep $image`"
	RIMG="`echo \"$TMPONE\" |sed '/^$/d'`"
done
echo "
currently used images (essential): `echo \"$RIMG\" |wc -l`
$LABEL
$RIMG" >> $LOGFILE

# store a list of essential images in a variable and add to log file
TMPONE="`echo \"$DIMG\"`
`echo \"$RIMG\"`"
EIMG="`echo \"$TMPONE\" |sort |uniq`"  # essential images
echo "
essential images: `echo \"$EIMG\" |wc -l`
$LABEL
$EIMG" >> $LOGFILE

# store a list of non-essential/unused images in a variable and add to log file
UIMG="$AIMG"  # initialize list with all images
for image in `echo "$EIMG" |awk '{print $1}'` ;do  # iterate through essential images
	TMPONE="`echo \"$UIMG\" |grep -v $image`"  # filter out essential images
	UIMG="$TMPONE"  # unused images
done
FLAGONE=''
if [[ -z `echo "$UIMG"` ]] ;then
	FLAGONE='empty'
	echo "
non-essential images: 0
$LABEL
(none)" >> $LOGFILE
else
	echo "
non-essential images: `echo \"$UIMG\" |wc -l`
$LABEL
$UIMG" >> $LOGFILE
fi

# remove/delete non-essential/unused images and add to log file
echo "" >> $LOGFILE
if [[ $FLAGONE == 'empty' ]] ;then
	echo "No images to remove.  Skipping..." >> $LOGFILE
else
	for image in `echo "$UIMG" |awk '{print $1}'` ;do
		echo "deleting ImageID: $image" >> $LOGFILE
		f_dryrun "docker rmi $image"
	done
fi
}

# execution
f_run () {

# clear terminal & set up log file
clear ;cat /dev/null > $LOGFILE

# run prune functions
f_containers ;f_images

# display log file contents
cat $LOGFILE
}

# script start
################################################################################

# variables
LOGFILE='/tmp/docker_prune.log'

# options
case $1 in
	'-r')  f_run ;;
	'-dr')  DRYRUN='true' ;f_run ;;
	'-h'|*)  f_help  ;;
esac

