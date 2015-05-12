#!/bin/bash
#######
## Adam Lathers
## alathers@gmail.com 4/15/2010

## Refactor the previous log and session sync scripts to make it a pull instead of push
## Done to put load on the backup instead of primary, and to allow transfers to run as non-root user
##   but still support setting of time/date/ACL info
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
#######


declare -a DIRLIST
declare -i x
BASEDIR=/LogStoragePath/logs
SOURCEHOST=`hostname`
if [[ $SOURCEHOST == *.site1.* ]]; then
  DESTHOST=loggingsystem1.site2
else
  DESTHOST='loggingsystem1.site1.expertcity.com'
fi
PIDFILEPATH=/tmp
PIDFILENAME=pidfile_logs
PIDFILE=${PIDFILEPATH}/${PIDFILENAME}
USER=system_svc
PARALLEL_TRANSFERS=5
OLDEST_SYNC=5
NEWEST_SYNC=0
MAXRUNLENGTH=4800 # Time in minutes for expected max run length
help=0
RETRIES=5
SLEEPBETWEENRETRIES=30
SYNCSUCCESS=0



# make sure that only one is running at a time.  Set a max run length to some large number of minutes, and auto-cleanup
if [ -f $PIDFILE ]; then
  OLDPID=`head -n 1 $PIDFILE`
  if [ -z $OLDPID ] || [ $OLDPID -lt 2 ]; then
    OLDPID=999999999
  fi

  if `ps -p $OLDPID > /dev/null`; then
    echo "PID ${OLDPID} tested and still running; exiting" >&2
  else
    echo "PID test and seems dead.  PIDFILE more than ${MAXRUNLENGTH} minutes old and $OLDPID not in PID table. Continuing"
  fi
fi
echo $$ > $PIDFILE


function usage {
echo "
$0 -s <source host> -d <destination host> -o <oldest sync range in days> -y <newest sync in days> -b <basedir path to sync> -p <number of parallel transfers>

  defaults: $0 -s $SOURCEHOST -d $DESTHOST -o 5 -y 0 -b /LogStoragePath/logs -p 5
"
exit 0
}

## Collect arguments and process.
while getopts  "s:d:o:y:b:p:h" flag
do
case "$flag" in
  s)
  SOURCEHOST=$OPTARG;;
  d)
  DESTHOST=$OPTARG;;
  o)
  OLDEST_SYNC=$OPTARG;;
  y)
  NEWEST_SYNC=$OPTARG;;
  p)
  PARALLEL_TRANSFERS=$OPTARG;;
  b)
  BASEDIR=$OPTARG;;
  h)
  help=1
  esac
done

#Run help info and quite if applicable
if [ $help -eq 1 ] ; then
  usage
fi

date >> $PIDFILE

ticket ()
{
        ## check for valid ticket
        /usr/kerberos/bin/klist -s
        ticket_test=$?
        if [ $ticket_test -ne 0 ] ; then
                echo "making ticket"
                /usr/kerberos/bin/kdestroy 2>&1 >> /dev/null
                /usr/kerberos/bin/kinit system_svc@SOMEDOMAIN.COM -k -t /uhome/system_svc/system_svc.keytab
        else
                echo "no need for ticket"
        fi
}

# Communicate with the "source" host to make a full file list.  Keep the window as small as feasible for daily work so that it runs quicker.
## Changes are regular enough that trusting a 3-5 day window is acceptable in general.  Run a job once/week or month to catch stragglers
init ()
{
echo "
source = $SOURCEHOST
dest = $DESTHOST
running with base = $BASEDIR
old= $OLDEST_SYNC
new = $NEWEST_SYNC


"
echo initing array

  for testrun in $(eval echo {1..${RETRIES}}); do
    if [ $SYNCSUCCESS == 0 ]; then
      if [ ${testrun} -gt 1 ]; then
          sleep ${SLEEPBETWEENRETRIES}
      fi
      file=`ssh -q -o GSSAPIDelegateCredentials=no ${USER}@${SOURCEHOST} "find $BASEDIR -type f -mtime -$OLDEST_SYNC -mtime +$NEWEST_SYNC | sed 's/\/LogStoragePath\/logs\///g'"` && SYNCSUCCESS=1
    fi
  done
  if [ $SYNCSUCCESS ]; then
    x=0
    for y in $file
    do
      if [ ! -z  $y ] ; then
        DIRLIST[$x]=$y
        x=x+1
      fi
    done
  else
    echo "Unable to build filelist.  Exiting"  >&2
  fi
  SYNCSUCCESS=0
}

# run multiple rsync commands in parallel.  takes better advantage of the system resources.  Throttle up or down as neededA
# run a set of transfers in parallel, then wait till they all exit before proceeding
copy()
{
  x=0
  echo "${#DIRLIST[*]} Total transfers to complete"
  while [ "$x" -lt "${#DIRLIST[*]}" ]
  do
    waittest=$(($x % $PARALLEL_TRANSFERS ))
  ## used to stagger transfers.  Do some number in parallel
    if [ $waittest -eq 0 ] ; then
      wait
    fi
    ticket

    if [ ! -z ${DIRLIST[$x]} ] ; then
  #echo "starting transfer number $x in slot number $(($x % $PARALLEL_TRANSFERS))"
      ( rsync -e 'ssh -q -o GSSAPIDelegateCredentials=no -c blowfish' --timeout=1500 -avzAX ${USER}@${SOURCEHOST}:${BASEDIR}/${DIRLIST[$x]} $BASEDIR) &
    sleep $(($RANDOM % $PARALLEL_TRANSFERS ))
    fi
    x=x+1

  done
  wait
  rm -f $PIDFILE
  exit 0
}

ticket
cd $BASEDIR
init
copy