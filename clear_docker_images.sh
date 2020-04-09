#!/bin/bash

# create list: cached docker images
LIST=`docker images -a |grep -i -e 'years ago' -e 'months ago' |awk '{print $1,$3}' |sort -n |uniq |column -t`
echo ;echo 'images:' ;echo "$LIST"

# create filter: running containers
FILTER=`docker ps -a |grep 'Up ' |awk '{print $2}' |sort |uniq |awk -F'/domino' '{print $2}' |awk -F':' '{print $1}'`
echo ;echo 'filter fields:' ;echo "$FILTER"

# prune list w/filter
RESULT=`echo "$LIST"`
for field in `echo "$FILTER"` ;do
  TMPONE=`echo "$RESULT" |grep -v -- "$field"`
  RESULT=`echo "$TMPONE"`
done
echo ;echo 'remaining images:' ;echo "$RESULT"

# disk before
df -h |grep -v docker |grep domino

# remove remaining images
TMPONE=`echo "$RESULT" |awk '{print $2}'`
echo
for imgid in `echo "$TMPONE"` ;do
  docker rmi $imgid
done

# disk after
df -h |grep -v docker |grep domino
