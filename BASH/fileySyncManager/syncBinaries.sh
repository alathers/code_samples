#!/bin/bash
#######
## Adam Lathers
## alathers@gmail.com 4/15/2010

## Refactor the previous log and session sync scripts to make it a pull instead of push
## Done to put load on the backup instead of primary, and to allow transfers to run as non-root user
##   but still support setting of time/date/ACL info
#
#
#
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#######


declare -a DIRLIST
declare -i x
BASEDIR=/LogStoragePath/records/
SOURCEHOST=logsys1.site1
DESTHOST=logsys1.site2
PIDFILE=/tmp/pidfile_rsync
USER=logfssvc


if [ -f $PIDFILE ]; then
   echo "PID file ($PIDFILE) exists.  Exiting" 1>&2
   exit
fi

date > $PIDFILE

init ()
{
  echo initing array
  ssh -q -o GSSAPIDelegateCredentials=no ${USER}@${SOURCEHOST} "ls -lt $BASEDIR" > /tmp/logs.txt
  file=`awk -F\  '{ print $9 }' /tmp/logs.txt`
  x=0
  for y in $file
  do
    DIRLIST[$x]=$y
    x=x+1
  done
}

copy()
{
  x=0
  while [ "$x" -lt "${#DIRLIST[*]}" ]
  do
    ( rsync -e 'ssh -q -o GSSAPIDelegateCredentials=no' -avzAX ${USER}@${SOURCEHOST}:${BASEDIR}/${DIRLIST[$x]} $BASEDIR) &
    x=x+1
    ( rsync -e 'ssh -q -o GSSAPIDelegateCredentials=no' -avzAX ${USER}@${SOURCEHOST}:${BASEDIR}/${DIRLIST[$x]} $BASEDIR) &
    x=x+1
    ( rsync -e 'ssh -q -o GSSAPIDelegateCredentials=no' -avzAX ${USER}@${SOURCEHOST}:${BASEDIR}/${DIRLIST[$x]} $BASEDIR ) &
    x=x+1

    if [ "$x" -ge "${#DIRLIST[*]}" ]
    then
      rm -f $PIDFILE
      exit 0
    fi
    wait
  done
}

/usr/kerberos/bin/kinit system_svc@SOMEDOMAIN.COM -k -t /uhome/system_svc/system_svc.keytab
cd $BASEDIR
init
copy