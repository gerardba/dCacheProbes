#!/bin/bash
#
#This scripts queries the infoDomain info cell to know if there are queued movers

exec 2>/dev/null

message=""
rc=0

show_usage() {
	echo "This scripts queries the infoDomain info cell to know if there are queued movers"
}

instance=`grep instance /opt/PICnodeInfo | cut -d= -f2`
case $instance in
        prod )
                dccore=xxxx.pic.es
		#This file is populated by the script /root/dCacheScripts/monitor_pinmanager/monitor_pin_manager.py using /etc/cron.d/pinmanager_monitor.cron
		pinManagerFile=/var/www/html/pinManagerLS-${instance}.txt
        ;;
        disk )
                dccore=xxxx.pic.es
		#This file is populated by the script /root/dCacheScripts/monitor_pinmanager/monitor_pin_manager.py using /etc/cron.d/pinmanager_monitor.cron
		pinManagerFile=/var/www/html/pinManagerLS-${instance}.txt
        ;;
        test )
                dccore=xxxx.pic.es
		#This file is populated by the script /root/dCacheScripts/monitor_pinmanager/monitor_pin_manager.py using /etc/cron.d/pinmanager_monitor.cron
		pinManagerFile=/var/www/html/pinManagerLS-${instance}.txt
        ;;
        * )
                echo "Unknown instance $instance. Check puppet maintanied /opt/PICnodeInfo file"
                exit 2
        ;;
esac

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
if [ "`find $pinManagerFile -mtime -1`" != "" ]; then 
	if [ `grep -i pinning $pinManagerFile | grep -v `date +%Y-%m-%d` | wc -l` -gt 1 ]; then
		message="[WARNING] Files in pinning state, check http://dcmon.pic.es/pinManagerLS-${instance}.txt. $message"
		rc=1
	fi
else 
	message="[WARNING] http://dcmon.pic.es/pinManagerLS-${instance}.txt is not up to date. $message"
	rc=1 
fi

QuerydCache="ssh -c blowfish -i <<IdentityFile>> -p 22223 -l admin $dccore 2>/dev/null | sed 's/\r//g'"

#p2pclient never actually queues. We do not care if stores are queued
queued=`echo -e "cd info\nstate ls\n..\nlogoff\n" | $QuerydCache | grep queued | grep -v store | grep -v p2p-clientqueue | grep -v '0 \[integer\]'`

if [ $? -eq 0 ]; then
	#We've queued movers
	message="[WARNING]: there are queued movers at $queued for dCache instance=$instance. $message"
	rc=1
else
	message="$message [OK] No movers queued at dCache instance=$instance."
fi

echo $message
exit $rc
