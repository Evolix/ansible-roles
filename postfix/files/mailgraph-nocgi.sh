#!/bin/sh
#
# Run Mailgraph without CGI
#
# https://wiki.evolix.org/HowtoMail/Mailgraph#installation-cgi-et-int%C3%A9gration-dans-apache
#

for path in /usr/share/mailgraph/mailgraph.cgi /usr/lib/cgi-bin/mailgraph.cgi; do
    if [ -e "${path}" ]; then
        MAILGRAPH_PATH="${path}"
    fi
done

MAILGRAPH_DIR=/var/www/mailgraph

umask 022

mkdir -p $MAILGRAPH_DIR

SCRIPT_NAME=mailgraph.cgi $MAILGRAPH_PATH | sed '1,2d ; s/mailgraph.cgi?// ; s/src="?/src="/' > $MAILGRAPH_DIR/index.html

for i in 0-n 0-e 0-g 1-n 1-e 1-g 2-n 2-e 2-g 3-n 3-e 3-g; do
    QUERY_STRING=$i $MAILGRAPH_PATH | sed '1,3d' > $MAILGRAPH_DIR/$i
done

