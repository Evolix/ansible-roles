#!/bin/sh

### BEGIN INIT INFO
# Provides:          minifirewall
# Required-Start:
# Required-Stop:
# Should-Start:      $network $syslog $named
# Should-Stop:       $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: start and stop the firewall
# Description:       Firewall designed for standalone server
### END INIT INFO

set -u

minifirewall_bin=/usr/local/sbin/minifirewall

case "${1:-}" in
    start)
        systemctl start minifirewall
        ;;
    stop)
        systemctl stop minifirewall
        ;;
    status)
        systemctl status minifirewall
        ;;
    restart|reload|condrestart)
        systemctl restart minifirewall
        ;;
    reset)
        "${minifirewall_bin}" reset
        ;;
    version)
        "${minifirewall_bin}" version
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|reset|version}"
        exit 1
esac

exit 0
