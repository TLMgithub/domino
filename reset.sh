#!/bin/bash
TESTDIR='/home/tony_matyas/ztest'

f_dirs () {
mkdir -p $WORKDIR/foo $WORKDIR/bar
mkdir -p $WORKDIR/1 $WORKDIR/2
mkdir -p $WORKDIR/2099 $WORKDIR/2218
date |tee -a $WORKDIR/foo/spam.txt $WORKDIR/bar/eggs.txt
date |tee -a $WORKDIR/1/spam.txt $WORKDIR/2/eggs.txt
date |tee -a $WORKDIR/2099/spam.txt $WORKDIR/2218/eggs.txt
}

f_files () {
mkdir -p $WORKDIR
rmdir $WORKDIR
date > $WORKDIR
}

rm -rf $TESTDIR

WORKDIR="$TESTDIR/domino/executor-01/executor/replicatorStorage/prepared"
f_dirs
#WORKDIR="$TESTDIR/domino/executor-02/executor/replicatorStorage/prepared"
#f_dirs

echo "
files:
`find $TESTDIR -type f`
"
echo "
dirs:
`find $TESTDIR -type d`
"
