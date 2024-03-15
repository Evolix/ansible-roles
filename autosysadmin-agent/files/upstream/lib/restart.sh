#!/bin/bash

# Specific functions for "restart" scripts

running_custom() {
    # Placeholder that returns 1, to prevent running if not redefined
    log_global "running_custom() function has not been redefined! Let's quit." 
    return 1
}

# Examine RUNNING variable and decide if the script should run or not
is_supposed_to_run() {
    if is_debug; then return 0; fi

    case ${RUNNING} in
    never)
        # log_global "is_supposed_to_run: no (never)"
        return 1
        ;;
    always)
        # log_global "is_supposed_to_run: yes (always)"
        return 0
        ;;
    nwh-fr)
        ! is_worktime
        rc=$?
        # if [ ${rc} -eq 0 ]; then
        #     log_global "is_supposed_to_run: yes (nwh-fr returned ${rc})"
        # else
        #     log_global "is_supposed_to_run: no (nwh-fr returned ${rc})"
        # fi
        return ${rc} 
        ;;
    nwh-ca)
        # Not implemented yet
        return 0
        ;;
    custom)
        running_custom
        rc=$?
        # if [ ${rc} -eq 0 ]; then
        #     log_global "is_supposed_to_run: yes (custom returned ${rc})"
        # else
        #     log_global "is_supposed_to_run: no (custom returned ${rc})"
        # fi
        return ${rc} 
        ;;
    esac
}

ensure_supposed_to_run_or_exit() {
    if ! is_supposed_to_run; then
        # simply quit (no logging, no notifications…)
        # log_global "${PROGNAME} is not supposed to run (RUNNING=${RUNNING})."
        exit 0
    fi
}

# Set of actions to do at the begining of a "restart" script
pre_restart() {
    initialize

    # Has it recently been run?
    ensure_not_too_soon_or_exit

    # Can we acquire a lock?
    acquire_lock_or_exit

    # Save important information
    save_server_state
}

# Set of actions to do at the end of a "restart" script
post_restart() {
    quit
}
