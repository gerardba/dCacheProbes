#!/bin/sh
#
#This script checks the website http://xxxxxxxx/checkmigrated/index.html so see if there are migration errors on pools.

website="http://xxxxx/checkmigrated/index.html"
ofile=/tmp/check_migrated.index.html

#### Timeout del check ####
timeout_check() {
PID=$1
sleep 15
kill -9 $PID >/dev/null 2>&1
if [ $? -eq 0 ]; then
        echo "[WARNING] Check timeout. This checks contacts http://xxxx.pic.es"
        exit 1
fi
}

timeout_check $$ &

#### Sensor en si ####

rm -f $ofile
wget ${website} -O ${ofile} -o /dev/null


grep "`date | cut -c -10`" $ofile 2>&1>/dev/null
dataActual=$?

if [ $dataActual -eq 0 ]; then
 grep "No Problems Found" $ofile  2>&1>/dev/null
 problemFound=$?

 if [ $problemFound -eq 0 ]; then
   echo "[OK] no pool migration problem detected"
   exit 0
 else
   echo "[WARNING] check $website, problem[s] detected"
   exit 1
 fi
else
 echo "[WARNING] $website is not updated"
 exit 1
fi


