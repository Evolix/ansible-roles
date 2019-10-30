#!/bin/sh
iptables -I INPUT -s $1 -j DROP
echo $1 >> /root/BLACKLIST-SSH
