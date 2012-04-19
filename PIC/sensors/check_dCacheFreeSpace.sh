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
                dccore=xxxxx.pic.es
        ;;
        test )
                dccore=xxxxxx.pic.es
        ;;
        * )
                echo "Unknown instance $instance. Check puppet maintanied /opt/PICnodeInfo file"
                exit 2
        ;;
esac


output=""
NOKoutput=""
rc=0
nom=""
espai=""
for i in `echo -e "cd PoolManager\nfree\n..\n                                                         \nlogoff\n"| ssh -c blowfish -i <<identityFile>> -p 22223 -l admin $dccore 2>/dev/null | sed 's/\r//g' | grep : | grep -v 'dmg.util.CommandExitException'`; do 
	if [ "$i" = ":" ]; then continue; fi
	case $nom in
		"") 
			nom=$i
			continue
		;;
		*atlas*)
			minFreeSpace=20000000000000 #20TB
		;;	
		*cms*)
			minFreeSpace=20000000000000 #20TB
		;;	
		*lhcb*)
			minFreeSpace=2000000000000 #2TB
		;;	
		*t2k*)
			minFreeSpace=0 #No gestionen espai en disc aixi que passem de si omplen
		;;	
		*)
			minFreeSpace=100000000000 #100GB
		;;
	esac
	if [ $i -gt $minFreeSpace ]; then #If there are more than 8GBytes
		let warnFreeSpace=2*$minFreeSpace
		if [ $i -gt $warnFreeSpace ]; then
			output="$output,$nom:$i"
		else
			if [ $rc -eq 0 ]; then rc=1; fi
			NOKoutput="[WARNING] $nom:$i,$NOKoutput"
		fi
	else
		NOKoutput="[CRITICAL] $nom:$i,$NOKoutput"
		rc=2
	fi
	nom=""
done

if [ $rc -eq 0 ]; then #No tenim cap problema
	echo "[OK] Freespace is $output"
	exit $rc
else
	echo $NOKoutput
	exit $rc
fi

