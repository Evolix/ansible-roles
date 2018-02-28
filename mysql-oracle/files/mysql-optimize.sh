#!/bin/sh

# Do some weekly optimizations.
# Reset the cache to avoid fragmentation.
mysql --defaults-extra-file=/etc/mysql/debian.cnf -e "RESET QUERY CACHE;"
