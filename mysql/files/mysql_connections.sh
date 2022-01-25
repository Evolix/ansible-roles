#!/bin/sh

# Example:
# # mysql_compact_processes 
# *************************** 1. row ***************************
# host_short: 
#      users: system user
#  processes: 1
# *************************** 2. row ***************************
# host_short: 31.170.X.Z
#      users: repl
#  processes: 1
# *************************** 3. row ***************************
# host_short: sql00.evolix.net
#      users: repl
#  processes: 1
# *************************** 4. row ***************************
# host_short: sql02.evolix.net
#      users: repl
#  processes: 1
# *************************** 5. row ***************************
# host_short: localhost
#      users: mysqladmin,percona
#  processes: 2
# *************************** 6. row ***************************
# host_short: prod10.evolix.net
#      users: user1,user2
#  processes: 11
# *************************** 7. row ***************************
# host_short: prod11.evolix.net
#      users: user3,user4,user5
#  processes: 312


set -e

mysql -e "SELECT SUBSTRING_INDEX(host, ':', 1) AS host_short, GROUP_CONCAT(DISTINCT USER) AS users, COUNT(*) AS processes FROM information_schema.processlist GROUP BY host_short ORDER BY processes, host_short\G"
