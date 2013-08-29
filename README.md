# Readme for dns-direct

# abstract

This script checks your external IP against a DNS record and if they differ it
updates the DNS record via bind's nsupdate.

# INSTALL

To install dns-direct clone this repository to a directory you'd like to use.
It doesn't have to be the internet gateway, any machines that satisfies the
dependencies is enough.

  1. copy dns-direct.conf.example to dns-direct.conf and adopt your settings.
  2. create a symmetric HMAC-MD5 key to use with bind by using dnssec-keygen
     and also copy the key to here
  3. configure your bind-server on the server-side to accept updates for the
     zone containing your $HOST and $AdditionalHosts from the key you created.
     You can use dns-direct.bind-config as a hint
  4. test out by running dns-direct.sh from your shell (optionally with the
     parameter "debug")
  5. configure cron to run dns-direct.sh at a regular interval (or simply copy
     dns-direct.cron to /etc/cron.d/dns-direct)
  6. enjoy the automatically updating dns-record

I tried to properly document every detail in each file, if I missed something
or took it for granted please tell me.


# Dependencies

  * run-parts from debian package "debianutils"
  * nsupdate and dig from debian package "dnsutils"
  * curl from debian package "curl"

# origins

this script was developed on the idea of dnsactual written by Ernest Danton (It
can be found on http://freedns.afraid.org/scripts/dnsactual.sh.txt).
