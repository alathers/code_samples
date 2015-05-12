#!/bin/bash
#######
#
# Adam lathers   5/25/2011
# adam.lathers@citrix.com
#
# A simple host foot-printer to use for things like host decom process
#
#
#
#  License: This is for inspection only, no re-use allowed without written consent from author.
#
#######

echo "
#########     `/bin/hostname`       ###########"


echo "
Hardware info"
/usr/sbin/dmidecode | /bin/egrep 'Product Name:'



echo "

Host IPs"
/sbin/ifconfig | /bin/egrep inet\  | /bin/awk {'print $2'} | /bin/awk -F: {'print $2'} | /bin/egrep -v 127.0.0.1

echo "
#########
"



echo "Host DNS"
for h in $(/sbin/ifconfig | /bin/egrep inet\  | /bin/awk {'print $2'} | /bin/awk -F: {'print $2'} | /bin/egrep -v 127.0.0.1); do
  /usr/bin/host $h
done

echo "
#########
"

echo "Reverse DNS"
for h in $(/sbin/ifconfig | /bin/egrep inet\  | /bin/awk {'print $2'} | /bin/awk -F: {'print $2'} | /bin/egrep -v 127.0.0.1); do
        /usr/bin/host `/usr/bin/host $h | /bin/awk {'print $NF'} | /bin/sed 's/.$//g'`
done

echo "
################################################
"
