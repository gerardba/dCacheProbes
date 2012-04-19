#!/bin/bash

#### Timeout del check ####
timeout_check() {
PID=$1
sleep 15
kill -9 $PID >/dev/null 2>&1
if [ $? -eq 0 ]; then
        echo "[WARNING] Check timeout. This checks contacts $dccore"
        exit 1
fi
}

timeout_check $$ &

#### Sensor en si ####
if [ $# -eq 1 ]; then
	instance="$1"
else
	instance=`grep instance /opt/PICnodeInfo | cut -d= -f2`
fi

case $instance in
        prod )
                dccore=xxx.pic.es
        ;;
        disk )
                dccore=xxxxxxx.pic.es
        ;;
        test )
                dccore=xxxx.pic.es
        ;;
        * )
                echo "Unknown instance $instance. Check puppet maintanied /opt/PICnodeInfo file"
                exit 2
        ;;
esac


output=""
NOKoutput=""
rc=0

cmd=$(echo -e "cd SrmSpaceManager\nls\n..\n                                                         \nlogoff\n"| ssh -c blowfish -i <<identityFile>> -p 22223 -l admin $dccore 2>/dev/null | sed 's/\r//g' | grep -i custodial | grep -i "expiration:NEVER" | grep -i vogroup | grep -v 'dmg.util.CommandExitException')
IFS="
"

for i in $cmd; do 
	#Get Info
	tokenID=$(echo $i | awk '{print $1}'); 
	size=$(echo $i | awk -F "size:" '{print $2}' | awk '{print $1}');
	used=$(echo $i | awk -F "used:" '{print $2}' | awk '{print $1}');
	description=$(echo $i | awk -F "description:" '{print $2}' | awk '{print $1}');
	
	let available=$size-$used
	let warnFreeSpace=50*$size/100
	let critFreeSpace=75*$size/100
	
	if [ $used -ge $critFreeSpace ]; then 
		NOKoutput="[CRITICAL] $description: tokenID:$tokenID, size:$size, used:$used, free:$available; $NOKoutput exceeds 75% of space"
                rc=2
	elif [ $used -ge $warnFreeSpace ]; then
			
		NOKoutput="[WARNING] $description: tokenID: $tokenID,size:$size, used:$used, free:$available; $NOKoutput exceeds 50% of space"
		if [ $rc -eq 0 ]; then rc=1; fi
	fi
done

if [ $rc -eq 0 ]; then 
	echo "[OK] Freespace is OK"
	exit $rc
else
	echo $NOKoutput
	exit $rc
fi

