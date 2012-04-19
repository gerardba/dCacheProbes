#!/bin/bash
#Checks that all dCache processes configured in node_config file are running in the machine
#and the default designated ports listening.


#################Parameters#############################

instance=`grep instance /opt/PICnodeInfo | cut -d= -f2`
node_type=`grep node_type /opt/PICnodeInfo | cut -d= -f2`
dCacheVersion=`grep dCacheVersion /opt/PICnodeInfo | cut -d= -f2`
dcachelayout=/opt/d-cache/etc/layouts/`grep dcache.layout /opt/d-cache/etc/dcache.conf | cut -d= -f2`.conf

case $instance in
	prod )
		dcip=xxxx.pic.es #dCache information provider server
		dccore="193.109.17.x"
	;;
	test )
		dcip=xxxxxx.pic.es #dCache information provider server
		dccore="193.109.17.x"
	;;
	disk )
		dcip=xxxxx.pic.es #dCache information provider server
		dccore="193.109.17.x"
	;;
	*)
		echo "Unknown instance $instance. Check puppet maintanied /opt/PICnodeInfo file"
		exit 2
	;;
esac
cellinfo=/tmp/cellInfo.html
netstat=/tmp/netstat.tmp

#################### Timeout del check ##################
timeout_check() {
PID=$1
sleep 15
kill -9 $PID >/dev/null 2>&1
if [ $? -eq 0 ]; then
        echo "Sensor timeout. This sensor contacts dccore ($dccore) and $dcip."
        exit 1
fi
}

timeout_check $$ &
##################monitoring script#####################

case $node_type in
	srmdb )
		echo "This server only needs to run dCache in emergency cases, node_type=$node_type"
		exit 0
	;;
	PGSQLstandby|dcmon )
		echo "This server does not need to run this check because its node_type=$node_type"
		exit 0
	;;
esac

output=""
rc=0
rm -f $cellinfo $netstat
if [ "`uname`" == "SunOS" ] 
then
  /opt/csw/bin/links -dump http://$dcip:2288/cellInfo > $cellinfo  #In Solaris to run this you need to install links, at PIC we've done this way: pkg-get upgrade common; pkg-get install links
  grepJava="`ps -ef | grep java | grep -v '/usr/java/bin/java' | grep -cv grep`"
  hostname=`hostname`
  netstat -n > $netstat
else
  links -dump http://$dcip:2288/cellInfo > $cellinfo
  grepJava="`ps --no-headers -fC java | grep -c d-cache`"
  netstat -putan > $netstat
  hostname=`hostname -s`
	#For all linux server we check that the system tunning is in place by checking one of the tricky properties
  proc=`ps --no-headers -fC java | grep  d-cache | awk '{print $2}' | head -1`
  if [ `grep "Max open files" /proc/$proc/limits | grep -c 65535` -ne 1 ]; then output="$output [WARNING] Tunning not applied"; rc=1; fi
fi

if [ ! -s $cellinfo ]; then
	echo "$cellinfo couldn't be read properly, maybe links is not installed"
	exit 1
fi

#All dCache nodes should have connections to its intance dccore
if [ `grep -c $dccore $netstat` -lt 1 ];
then
	output="[CRITICAL] No connection with dccore for dCache instance=$instance ($dccore) detected. $output"
	rc=2
else
	output="$output [OK] Connection with dccore established: `echo $netstat | grep $dccore`."
fi

procStatus="`/opt/d-cache/bin/dcache status | grep running`"

function checkResults {
	#This function modifies nagios sensor return code (rc) and nagios sensor message (output).
	#noteval=1 should be included for those cells we have nothing to check.
	#dCacheStatus: should be 1 if a dcache status finds the cell (only when there is a 1 to 1 mapping betwen cell and java proc/dcache daemon).
	#grepNetstat: should be 1 if the cell is listening in the right port
	#grepCellInfo: should be 1 if the cell is found in dCache's info system

	if [ "$noteval" = "1"  ]; then 
		output="$output [?] $cell."
	elif [ $dCacheStatus -ne 1 ]; then
		output="[CRITICAL] dCacheDomain for Cell $cell is down. $output"
		rc=2
	elif [ $grepNetstat -ne 1 ]; then
		output="[CRITICAL] Cell $cell is not listening for new connections, check netstat. $output"
		rc=2
	elif [ `echo $grepCellInfo | grep -ic Offline` -ne 0 ]; then
		output="[CRITICAL] according to http://$dcip:2288/cellinfo $cell is Offline. $output"
		rc=2
	else
		if [ $rc -eq 0 ]; then #We sort so that if there is no issue not evaluated procs go to the end
			output="[OK] $cell. $output"
		else
			output="$output [OK] $cell."
		fi
	fi
}


#We count the number of pools running in the server and add 1 just to fit in the standard dCache case where we number 1 2 3 ...
let poolCount=`grep -ci "${hostname}_" $cellinfo`+1

#We get the list of services which should be on the server
for cell in `egrep "^\[.+/.+\]" $dcachelayout | cut -d/ -f2 | cut -d] -f1`; do
	noteval=0
	standardcell="no"
	case $cell in
		gsidcap)
			standardcell="yes"
			grepNetstat=`grep -c 0.0.0.0:22128 $netstat`
		;;
		dcap)
			standardcell="yes"
			grepNetstat=`grep -c 0.0.0.0:22125 $netstat`
		;;
		gridftp)
			standardcell="yes"
#			grepNetstat=`cat $netstat | grep -c 0.0.0.0:2811`
			if  [ `grep -c 0.0.0.0:2811 $netstat` -eq 1 ]; then
				grepNetstat=`echo quit | nc -w 5 localhost 2811 | grep -ic "220 GSI FTP Door ready"`
			fi
		;;
		xrootd)
			standardcell="yes"
			grepNetstat=`grep -c 0.0.0.0:1094 $netstat`
		;;
		webdav)
			standardcell="yes"
			grepNetstat=`grep -c 0.0.0.0:2880 $netstat`
		;;
		srm)
			standardcell="yes"
			grepNetstat=`grep -c 0.0.0.0:8443 $netstat`
		;;
		pool)
		  	grepCellInfo=`grep -i "${hostname}_" $cellinfo`
			let poolCount=$poolCount-1 #This will not work if pools are not in sequence
			dCacheStatus=`echo $procStatus | grep -c ${hostname}_$poolCount` #We count the number of pools running in the server and add 1 just to fit in the standard dCacheStatus = 1 = OK
			grepNetstat=1 #Pools should not listen any port
		;;
	#Cells with no dedicated java process in PIC default cell-proc setup, thus they do not appear in the dcache status output.
		poolmanager)
			dCacheStatus=`echo $procStatus | grep -c dCacheDomain` #We select this cell to check on the daemon.
			grepCellInfo=`grep -i "${cell}-${hostname}" $cellinfo`
			grepNetstat=`grep -c 0.0.0.0:11111 $netstat` #The port might be from another service, but running in the dCacheDomain.
		;;
		pnfsmanager)
			grepNetstat=1 #Nothing to be listening to
			dCacheStatus=`echo $procStatus | grep -c namespaceDomain` #We select this cell to check on the daemon.
			grepCellInfo=`grep -i "${cell}-${hostname}" $cellinfo`
		;;
		loginbroker)
			grepNetstat=1 #Nothing to be listening to
			dCacheStatus=1
			grepCellInfo=`grep -i "${cell}-${hostname}" $cellinfo`
		;;
		srm-loginbroker)
			grepNetstat=1 #Nothing to be listening to
			dCacheStatus=1
			grepCellInfo=`grep -i "${cell}-${hostname}" $cellinfo`
		;;
	#Cells with no info in the dCache web
		info)
			grepNetstat=`grep -c  127.0.0.1:22112 $netstat`
			dCacheStatus=`echo $procStatus | grep -c infoDomain` #We select this cell to check on the daemon.
			grepCellInfo=1
		;;
		nfsv3)
			grepNetstat=`grep tcp  $netstat | grep -c 0.0.0.0:2049`
			dCacheStatus=`echo $procStatus | grep -c nfsDomain` #We select this cell to check on the daemon.
			grepCellInfo=1
		;;
		httpd)
			dCacheStatus=1
			grepNetstat=`grep -c  0.0.0.0:2288 $netstat`
			grepCellInfo=1
		;;
		admin)
			grepNetstat=`grep -c  0.0.0.0:22223 $netstat`
			dCacheStatus=1
			grepCellInfo=1
		;;
		*)
			noteval=1
		;;
	esac
	if [ "$standardcell" = "yes" ]; then
		       dCacheStatus=`echo $procStatus | grep -c $cell`
		       grepCellInfo=`grep -i "${cell}-${hostname}" $cellinfo`
	fi

	checkResults
done

#We get the number of Java Daemons which should be on the server
JavaProcs=`egrep -c "^\[.+Domain]" $dcachelayout`

#Check how many java daemons are running in the host
if [ $grepJava -gt $JavaProcs ]; then
	if [ $rc -eq 0 ]; then rc=1; fi
	output="[WARNING] Too many java procs running ($grepJava -gt $JavaProcs). $output"
else
	if [ $grepJava -lt $JavaProcs ]; then
		output="[CRITICAL] Too few java procs running ($grepJava -lt $JavaProcs). $output"
		rc=2
	fi
fi

#Check JAVA version
jversion=`java -version 2>&1 | grep version`
if [ "`echo $jversion | awk '{print $3}' | xargs echo | cut -d. -f1,2`" == "1.6" ]; then
	output="$output $jversion"
else
	if [ "$rc" = "0" ]; then rc=1; fi
	output="[WARNING] $jversion. $output"
fi

echo $output
exit $rc


