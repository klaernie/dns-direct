#!/bin/bash
##############################################################################
#
#  application name: dnsactual3
#  Author: Andre Klärner
#  Date: December 2010
##############################################################################

# Base Folder
BASE=/root/dns-direct
# Logfile
LOGFILE="$BASE/dnsactual.log"
LASTRUN="$BASE/dnsactual.lastrun"
# URL to check for current IP
CHECK_URL="https://port1.mia.ak-online.be/ip.php"

HOST=vpn.ak-online.be.
AlsoUpdate="debs.ak-online.be. hive.ak-online.be. mainframe.ak-online.be. linksys.ak-online.be. mail.ak-online.be. stats.ak-online.be. wiki.ak-online.be. light.ak-online.be. fynn.ak-online.be. olli.ak-online.be. sapdeb2.ak-online.be."
#NS=mia.ak-online.be.
NS="83.169.34.170"
TTL=60
KEYFILE=$BASE/Kdnsupdate.debs.ak-online.be.+157+05115.private

DEBUG=1
DEBUG=`test "$*" = "debug" ; echo $?`

FORCE=0

OldIP=$(dig @$NS +short +tries=10 $HOST 2>>tmpfile)
[ $DEBUG -eq 0 ] && echo OldIP: $OldIP
[ $FORCE -eq 1 ] && OldIP="x.x.x."
CurreIP=$(curl -sS -3 -4 --user-agent "curl/7.21.0 (i486-pc-linux-gnu) dnsactual" $CHECK_URL 2>>tmpfile)
[ $DEBUG -eq 0 ] && echo NewIP: $CurreIP
if [ -z "$CurreIP" -o -z "$OldIP" ]
then
	echo "Retrieval of old or new IP failed:"
	cat tmpfile
	rm tmpfile
	exit 1
fi
if [ "$CurreIP" = "$OldIP" ]
then
	# Both IPs are equal
	[ $DEBUG -eq 0 ] && echo "Update not required..."
	exit 0
else
	# The IP might have changed

	if [ "$OldIP" = ";; connection timed out; no servers could be reached" ]
	then 
		echo "Update not possible, no DNS server was reachable"
		echo "running failure hooks:"
		run-parts "$BASE/fail-hooks.d"
		exit 2
	fi

	echo -e "Updating $HOST\n via nsupdate at $NS\n from IP $OldIP\n   to IP $CurreIP"
	(
		echo server $NS
		for iHOST in $HOST $AlsoUpdate
		do
			echo update delete $iHOST A
			echo update add $iHOST $TTL A $CurreIP
		done
		[ $DEBUG -eq 0 ] && echo show
		echo send
		[ $DEBUG -eq 0 ] && echo answer
	) | tee $LASTRUN | nsupdate -k $KEYFILE -v 2>> tmpfile
	if [ $? -eq 0 ]
	then
	/etc/init.d/aiccu restart
		echo `date` "Updated $HOST@$NS from $OldIP to $CurreIP" >> $LOGFILE
		echo Update successful
		rm tmpfile
		exit 0
	else
	/etc/init.d/aiccu restart
		echo `date` "Update from $OldIP to $CurreIP for Host $HOST@$NS failed." >> $LOGFILE
		echo Update failed
		echo
		echo "Output of nsupdate-run: "
		cat tmpfile
		exit 1
	fi
fi
