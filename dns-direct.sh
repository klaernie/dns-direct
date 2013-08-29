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

# initialize $DEBUG with 1
DEBUG=1
# and set it to 0 (test's returnstatus on success) if "debug" was given as
# argument
DEBUG=`test "$*" = "debug" ; echo $?`

# define a function to output debugging info
function debug(){
	if [ $DEBUG -eq 0 ]
	then
		echo $@
	fi
}

# In case there is a temporary problem or to help testing it can help setting
# this to 1 to force the update even if the old value is correct
FORCE=0

# query the $NS for the $HOST, let dig only return the value. Also retry a few
# times if the first ones fail (which might be the case if the DSL-line is
# saturated by traffic or the connection was down while the script started)
OldIP=$(dig @$NS +short +tries=10 A $HOST 2>>tmpfile)

debug "OldIP: $OldIP"

# If $FORCE is set reset the $OldIP to something really invalid which would
# never be returned as an A record from the DNS-server
[ $FORCE -eq 1 ] && OldIP="x.x.x."

# Fetch the current external IP by asking our trusting $CHECK_URL
CurreIP=$(curl -sS -3 -4 --user-agent "curl/7.21.0 (i486-pc-linux-gnu) dns-direct" $CHECK_URL 2>>tmpfile)
# options used for curl:
#	-sS : no regular output, but bark on errors
#	-3  : use SSLv3
#	-4  : use IPv4, as the IPv6 is useless and probably static anyway
#	--user-agent: make dns-direct recognizable for your httpd-logfile analyzer

debug "NewIP: $CurreIP"

# if either the OldIP or the new IP are empty
if [ -z "$CurreIP" -o -z "$OldIP" ]
then
	# bark out
	echo "Retrieval of old or new IP failed:"

	# put the content of tmpfile to standard out
	cat tmpfile
	# and remove the tmpfile again
	rm tmpfile
	# also exit non-zero, so that cron knows that something failed
	exit 1
fi

# if both IPs are equal
if [ "$CurreIP" = "$OldIP" ]
then
	debug "Update not required..."
	# exit gracefully
	exit 0
else
	# The IP might have changed or the update was forced

	# let's check if dig returned an timeout
	if [ "$OldIP" = ";; connection timed out; no servers could be reached" ]
	then
		# than bark
		echo "Update not possible, no DNS server was reachable"
		# and run the failure hooks
		echo "running failure hooks:"
		run-parts "$BASE/fail-hooks.d"
		# and finally exit with error
		exit 2
	fi

	# if we made to here there should be an update, so start composing the output for the user
	echo -e "Updating $HOST\n via nsupdate at $NS\n from IP $OldIP\n   to IP $CurreIP"

	# and also compose the update commands for nsupdate:
	# template:
	#   server $NS
	#   update delete $HOST A
	#   update add $HOST $TTL A $CurreIP
	#   … repeat the last two for every $AlsoUpdate host
	#   send
	(
		echo server $NS
		for iHOST in $HOST $AlsoUpdate
		do
			echo update delete $iHOST A
			echo update add $iHOST $TTL A $CurreIP
		done
		# if debugging is enabled also show what we are going to do
		[ $DEBUG -eq 0 ] && echo show
		echo send
		# and what the server sent us back
		[ $DEBUG -eq 0 ] && echo answer
	) | tee $LASTRUN | nsupdate -k $KEYFILE -v 2>> tmpfile
	#  pipe this to $LASTRUN and finally feed it to nsupdate, which should
	#  put it's own (non-server) errors to tmpfile

	# if all went well
	if [ $? -eq 0 ]
	then
		# write the update to the logfile
		echo `date` "Updated $HOST@$NS from $OldIP to $CurreIP" >> $LOGFILE

		# and complete the output to the user
		echo Update successful

		# also run the hooks
		echo running success-hooks:
		run-parts "$BASE/success-hooks.d"

		# remove the tmpfile
		rm tmpfile
		# and exit gracefully
		exit 0
	else
		# write the failure to the log
		echo `date` "Update from $OldIP to $CurreIP for Host $HOST@$NS failed." >> $LOGFILE

		# and inform the user
		echo Update failed
		echo

		# and also dump the answer of nsupdate
		echo "Output of nsupdate-run: "
		cat tmpfile

		# and exit out
		exit 1
	fi # $? -eq ß
fi # $CurreIP = $OldIP
