#!/bin/bash

###
#
#  Adam Lathers
#    alathers@gmail.com
#
#  Tool to manage prune, sync, and compression of log files on massive file store
#    Do rsync in parallel to properly saturate link
#
# Order of operations
#  1.) purse old files
#  2.) purge empty directories   N/A for logstore hosts
#  3.) zip files
#  4.) transfer
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
##
logfile=/tmp/cron.logs/manageSync.log
#echo "Jobstart: `date`" >> $logfile


scriptname=$0
PID=$$
pidfile=/tmp/pidfile_managesync
if [ -f $pidfile ] ; then
  oldpid=`head -n 1 $pidfile`
  #echo "pidfile exists with PID $oldpid "
  ps auxwww | egrep "${oldpid}" | egrep "${scriptname}" >> /dev/null
  stale=$?
  if [ $stale -ne 0 ] ; then
    echo "It appears that there is a stale PID file here: ${pidfile} for PID: ${oldpid}.  Please investigate"
  #else
    #echo "Job started on `tail -n 1 $pidfile`"
  fi
  exit
else
  echo $PID > $pidfile
  echo -n "Job started:  " >> $logfile
  date >> $pidfile
fi

hostname=`hostname | sed 's/.exper.*//g'`
logretention=25
sessionretention=90

`echo $hostname | egrep site1 2>&1 >> /dev/null`
loccheck=$?
if [ $loccheck -eq 0 ] ; then
  remotehost=`echo $hostname | sed 's/site1/site2/g'`
  loc="site1"
  remoteloc="site2"
else
        remotehost=`echo $hostname | sed 's/site2/site1/g'`
  loc="site2"
  remoteloc="site1"

fi

`echo $hostname | egrep logstore 2>&1 >> /dev/null`
typecheck=$?
if [ $typecheck -eq 0 ] ; then
  find /LogStoragePath/logs/ -type f -mtime +$logretention ! -name ".*" -exec rm -f \{\} \;
  /LogStoragePath/misc/bzip2cron.sh >> /LogStoragePath/cron.logs/bzip2-cron.log 2>&1
  /LogStoragePath/misc/syncLogs.sh -s $hostname -d $remotehost -o 5 -y 0 -b /LogStoragePath/logs -p 5 2>&1 >> /LogStoragePath/cron.logs/sync_to_${remoteloc}.log

else
  find /LogStoragePath/records/sessions -type f -mtime +$sessionretention -exec /LogStoragePath/misc/SessionDeletion.sh -f {} \;
  find /LogStoragePath/records/sessions -type d -empty -mtime +$sessionretention -exec /LogStoragePath/misc/SessionDeletion.sh -d {} \;
  /LogStoragePath/misc/syncSessions.sh 2>&1 >> /LogStoragePath/cron.logs/sync_logs_to_${remoteloc}.log
fi

echo "Jobend: `date`" >> $logfile
rm ${pidfile}