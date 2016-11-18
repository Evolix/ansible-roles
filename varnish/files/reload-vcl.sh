#!/bin/sh
UUID=`cat /proc/sys/kernel/random/uuid`
/usr/sbin/varnishd -C -f /etc/varnish/default.vcl >/dev/null \
 &&/usr/bin/varnishadm -T localhost:6082 -S /etc/varnish/secret "vcl.load vcl_$UUID /etc/varnish/default.vcl" \
 && /usr/bin/varnishadm -T localhost:6082 -S /etc/varnish/secret "vcl.use vcl_$UUID"
