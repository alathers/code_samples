#!/bin/sh
#
# New and improved script to bzip up the MASSIVE pile of logs stored on
#  logging servers.  Meant to play nicely with other crons run on these hosts
#  that handle deleting and sync as well
#
#  Adam Lathers
#  alathers@gmail.com
#  12/28/2012
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
############

lower=2
upper=4
PID=$$
pidfile='/tmp/pidfile_gzip'
scriptname=$0

if [ -f $pidfile ]; then
  oldpid=`head -n 1 $pidfile`
  ps auxwww | egrep "${oldpid}" | egrep "${scriptname}" >> /dev/null
  stale=$?
  if [ $stale -ne 0 ] ; then
    echo "Error running ${scriptname}: It appears that there is a stale PID file here: ${pidfile} for PID: ${oldpid}.  Please investigate"
  #else
    #echo "Job started on `tail -n 1 $pidfile`"
  fi
  exit
else
  echo $PID > $pidfile
  echo -n "Job started:  " >> ${pidfile}
  date >> $pidfile
  cd /LogStoragePath/logs
  find /LogStoragePath/logs/ -type f -mtime +${lower} -mtime -${upper} -name "*.log" -exec gzip -5 \{\} \;
  rm /tmp/pidfile_gzip
fi