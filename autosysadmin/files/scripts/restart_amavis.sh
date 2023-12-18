#!/bin/bash

restart_amavis() {
    /etc/init.d/amavis stop 2>/dev/null
    /etc/init.d/clamav-freshclam stop 2>/dev/null
    /etc/init.d/clamav-daemon stop 2>/dev/null
    
    if systemctl is-enabled --quiet 'clamav-freshclam.service'
    then
        freshclam
        log_action "Mise à jour des définitions antivirus"
    fi
    
    if systemctl is-enabled --quiet 'clamav-daemon.service'
    then
        /etc/init.d/clamav-daemon start
        log_action "Redémarrage de clamav-daemon"
    else
        log 'Error, clamav not installed'
    fi
    
    if systemctl is-enabled --quiet 'clamav-freshclam.service'
    then
        /etc/init.d/clamav-freshclam start
        log_action "Redémarrage de clamav-freshclam"
    fi
    
    if systemctl is-enabled --quiet 'amavis.service'
    then
        /etc/init.d/amavis start
        log_action "Redémarrage de amavis"
    else
        log 'Error, amavis not installed'
    fi
}
