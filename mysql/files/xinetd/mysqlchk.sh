#!/bin/sh

# Ansible managed
#
# http://sysbible.org/x/2008/12/04/having-haproxy-check-mysql-status-through-a-xinetd-script/
#
# This script checks if a mysql server is healthy running on localhost. It will
# return:
#
# "HTTP/1.x 200 OK\r" (if mysql is running smoothly)
#
# - OR -
#
# "HTTP/1.x 500 Internal Server Error\r" (else)
#
# The purpose of this script is make haproxy capable of monitoring mysql properly
#
# Author: Unai Rodriguez
#
# It is recommended that a low-privileged-mysql user is created to be used by
# this script. Something like this:
#
# mysql> GRANT SELECT on mysql.* TO 'mysqlchkusr'@'localhost' \
#     -> IDENTIFIED BY '257retfg2uysg218' WITH GRANT OPTION;
# mysql> flush privileges;

TMP_FILE="/tmp/mysqlchk.out"
ERR_FILE="/tmp/mysqlchk.err"

#
# We perform a simple query that should return a few results :-p
#
/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf  -e "show databases;" > $TMP_FILE 2> $ERR_FILE

#
# Check the output. If it is not empty then everything is fine and we return
# something. Else, we just do not return anything.
#

if [ "$(/bin/cat $TMP_FILE)" != "" ]; then
        # mysql is fine, return http 200
        /bin/echo -e "HTTP/1.1 200 OK\r\n"
        /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
        /bin/echo -e "\r\n"
        /bin/echo -e "MySQL is running.\r\n"
        /bin/echo -e "\r\n"
else
        # mysql is fine, return http 503
        /bin/echo -e "HTTP/1.1 503 Service Unavailable\r\n"
        /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
        /bin/echo -e "\r\n"
        /bin/echo -e "MySQL is *down*.\r\n"
        /bin/echo -e "\r\n"
fi
