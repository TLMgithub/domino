#!/bin/bash
clear

echo ;echo "ids & images: all"
AIMAGES="`docker images |grep -v REPOSITORY |sort |awk '{print $3,$1":"$2}' |column -t`"
echo "$AIMAGES"

echo ;echo "ids & images: non-critical"
IMAGES="`echo \"$AIMAGES\" |grep -vi -e 'executor' -e 'fluent' |sed '/^$/d'`"
echo "$IMAGES"

echo ;echo "images: current runs"
RUNS="`docker ps |grep -v CONTAINER |awk '{print $2}' |sort |column -t`"
echo "$RUNS"

echo ;echo "ids: current runs"
for run in `echo "$RUNS"` ;do
  ADD="`echo \"$IMAGES\" |grep $run |awk '{print $1}' |sed '/^$/d'`"
  INIT="$RUNIDS
$ADD"
  RUNIDS="`echo \"$INIT\" |sed '/^$/d'`"
done
echo "$RUNIDS"

echo ;echo "ids: unused"
ADD="`echo \"$IMAGES\" |awk '{print $1}' |sed '/^$/d'`"
for run in `echo "$RUNIDS"` ;do
  OLDIDS="`echo \"$ADD\" |grep -v $run`"
  ADD="$OLDIDS"
done
echo "$OLDIDS"

echo ; echo "deleting unused images..."
for image in `echo "$OLDIDS"` ;do
  echo "deleting: `echo \"$IMAGES\" |grep $image`"
  docker rmi $image
done
