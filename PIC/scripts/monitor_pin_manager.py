#!/usr/bin/env python
#
# This script retries suspended transfers to tape
# author(s): Christopher Jung (iwr68)
# more documentation can be found in the dCache trac
# https://svn.rz.uni-karlsruhe.de/trac/dcache/wiki/AdminScriptsHeadnode
#
import sys, time, re, datetime, types, socket, os
sys.path.append('/opt/dCacheScripts/jPythonNebraska')
from dCacheAdmin import Admin, parseOpts, parse_DBParam
from dCacheErrors import *

import time
import datetime

infoToWrite='/var/www/html/pinManagerLS.txt'
PoolManager = 'PoolManager'
PnfsManager = 'PnfsManager'
PinManager = 'PinManager'


if __name__ == '__main__':
    kwOpts, passedOpts, givenOpts = parseOpts( sys.argv[1:] )

    info = parse_DBParam();
    try:
        a = Admin( info )
    except Exception, e:
        print "The following error occurred while trying to connect to the admin interface:"
        print e
        sys.exit(3)


    infoOutput=a.execute(PinManager,'ls')
    output=open(infoToWrite,'w')
    output.write(infoOutput)
    output.close()

    for line in infoOutput.split('\n'):
	res = re.search('total', line)
	if res != None:
		n = line.split(' ')
		osCommand='/usr/bin/gmetric -n Number_of_Pins -v '+ n[1] +' -t int16 -u Pins --dmax 10000'
		os.popen(osCommand)

#	No funciona amb 1.9.12 ja que nomes publica un numero
#	res = re.search('total number of pin requests', line)
#	if res != None:
#		n =  line.split(':')
#		osCommand='/usr/bin/gmetric -n Pin_Requests -v '+n[1]+' -t int16 -u Pin_Requests --dmax 10000'
#		os.popen(osCommand)
#
    os._exit(0)

