#!/bin/bash
#Parsing pool logs for a dead state in the las Pool Mode change

rc=0
message=""

for log in `ls /var/log/dc*Domain.log`; do
	connectionsTOdccore=`tail -1000 $log | grep -i 'Pool Mode' | tail -1 | grep 'dead\|disabled' | wc -l`
	if [ "$connectionsTOdccore" -gt "0" ];
	 then
	  message="$message [CRITICAL] This dCache pool seems to be dead: `tail -1000 $log | grep -i 'Pool Mode' | tail -1 | grep 'dead\|disabled'`"
	  rc=2
	else
	 #It could be to have a disabled state without the dead flag, it means the pool is Initializing.
		if [ "`uname`" = "SunOS" ]; then 
			totalSpacedcpool=`df -k /dcpool 2>/dev/null| grep dcpool | awk '{print $2}'`
		else
			totalSpacedcpool=`df -Pk /dcpool 2>/dev/null| grep dcpool | awk '{print $2}'`
		fi
		if [ `/opt/d-cache/bin/dcache pool ls  | grep dcpool | awk '{ sum+=($3/1024) } END { printf("%s", sum)}'` -gt $totalSpacedcpool ]; then #This usually does not work because the entry is just -.
			echo "WARNING: more Pool space allocated than total pool size"
			rc=1
		else
			message="$message [OK] No dead error found in dCache's log: `tail -1000 $log | grep -i 'Pool Mode' | tail -1`"
		fi 
	fi
done

echo $message
exit $rc

