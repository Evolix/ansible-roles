#!/bin/bash
echo $1 $2 is in $3 state > /var/run/keepalive.state
chmod og+r /var/run/keepalive.state
