#!/bin/bash

####################
#
#  Adam Lathers
#   alathers@gmail.com
#   
#   This tool is used to configure a legacy 32-bit machine to run some in-house developed code
#     The basic output values is making a decision based on physical processor count
#     which requires accounting for hypherthreading.  Also memory, and dedicate IP counts
#
#    Written in BASH as this is meant to be deployed to multiple OS versions with high variability in other scripting language variations
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
######################


#####
#
# Interfaces Block
#
#####

## First decide if all the interface blocks are properly configured.
###  If so, the count the number of matching subnets to identify how many instances are possible by IP address
list=`/sbin/ifconfig  | egrep inet\  | egrep -v 127.0.0.1 | awk {'print $2'} | awk -F: {'print $2'} | sort | sed 's/\.[0-9]*$//g'`
first=`echo "$list" | head -n 1`
expectedIPs=`echo "$list" | egrep -c $first`
ipcount=`/sbin/ifconfig | egrep inet\  | egrep -v '127.0.0.1' | wc -l`
ipblocks=$(($ipcount/$expectedIPs))

# Check to make sure host was built with an acceptable network allocation
for h in $list; do
  counttest=`echo "$list" | egrep -c $h`
  if [ $expectedIPs != $counttest ] ; then
    echo "failed, number of IPs per instance is not consistent.  Please check IP config"
    exit  1
  fi
done

#####
#
# CPU Block
#
#####

## Decide if hyper threading is enabled, and how many "blocks" of processors we have
###  We want one proc for the OS, and 2 procs per instance
procs=$((`egrep processor /proc/cpuinfo  | awk {'print $3'} | sort -n | tail -n 1`+1))
sibs=`egrep siblings /proc/cpuinfo  | awk {'print $3'} | sort -n | tail -n 1`
cores=`egrep cores /proc/cpuinfo | awk {'print $4'} | sort -n | tail -n 1`

if [ $cores = $sibs ] ; then
  # hypher threading is off
    proccount=$procs
else
  proccount=$(($procs/2))
fi

# require 2 per process, plus for for OS.  Order of operations ensures this works all in 1 calculation, / before - 
availprocs=$(($proccount/2-1))

#####
#
# Memory Block
#
#####

# Require 4GB per process
## For ease I will assume output is always in KB.  This might be sloppy, but likely sufficient for the lifetime of this tool
membase=`egrep MemTotal /proc/meminfo  | awk {'print $2'} | sed 's/.....$//g'`
memblocks=`echo $membase | awk "BEGIN{print int(($membase/60)+.5)}"  `

#####
#
# Decision Block
#
#####


if [ $ipblocks -eq $availprocs ] ; then
  if [ $ipblocks -eq $memblocks ] || [ $ipblocks -lt $memblocks ]; then
    instances=$ipblocks
  elif [ $ipblocks -gt $memblocks ] ; then
    instances=$memblocks
  fi
elif [ $ipblocks -lt $availprocs ] ; then
  if [ $ipblocks -eq $memblocks ] || [ $ipblocks -lt $memblocks ]; then
    instances=$ipblocks
  elif [ $ipblocks -gt $memblocks ] ; then
    instances=$memblocks
  fi
elif [ $ipblocks -gt $availprocs ]  ; then
   if [ $availprocs -eq $memblocks ] || [ $availprocs -lt $memblocks ]; then
    instances=$availprocs
  elif [ $availprocs -gt $memblocks ]  ; then
    instances=$memblocks
  fi
fi


loc=`hostname | cut -d\. -f2`

if [ "${loc}" != "" ]; then
    location="${loc}"
else
    echo "quitting, unknown on unacceptable location for use as Partition value"
    exit 1

fi

if [ $instances -eq 0 ] ; then
  echo "quitting, not valid for 1 or more instances"
  exit 1
else  
    subpart="${instances}"
fi




description=$(/bin/cat << "DESCRIPTIONFILE"
hostinfo {
    Site: LOC
}

Service Application {
    Partition: PARTITION
    SubPartition: INSTANCES
    Product: myapp
}



)

echo "${description}" | sed "s/PARTITION/${location}/g" | sed "s/INSTANCES/${instances}/g" | sed 's/LOC/${location}/g'



