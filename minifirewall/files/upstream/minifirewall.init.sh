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
show_systemctl_status() {
    systemctl --no-pager --output=cat --lines=30 status minifirewall.service
}

case "${1:-}" in
    start)
        systemctl start minifirewall.service
        show_systemctl_status
        ;;
    stop)
        systemctl stop minifirewall.service
        show_systemctl_status
        ;;
    status)
        show_systemctl_status
        ;;
    restart|reload|condrestart)
        systemctl restart minifirewall.service
        show_systemctl_status
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
