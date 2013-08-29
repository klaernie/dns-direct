#!/bin/bash
##############################################################################
#
#  application name: dns-direct
#  Author: Andre Klärner
#  Date: August 2013
##############################################################################

# change to the directory that dns-direct is running in
cd $(dirname $0)

# source the config
# TODO: support global config in /etc or searching it from different places
source dns-direct.conf

DEBUG=1
DEBUG=`test "$*" = "debug" ; echo $?`

# define a function to output debugging info
function debug(){
	if $DEBUG -eq 0
	then
		echo $@
	fi
}

FORCE=0

OldIP=$(dig @$NS +short +tries=10 A $HOST 2>>tmpfile)

debug "OldIP: $OldIP"

[ $FORCE -eq 1 ] && OldIP="x.x.x."
CurreIP=$(curl -sS -3 -4 --user-agent "curl/7.21.0 (i486-pc-linux-gnu) dnsactual" $CHECK_URL 2>>tmpfile)

debug "NewIP: $CurreIP"

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
	debug "Update not required..."
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
