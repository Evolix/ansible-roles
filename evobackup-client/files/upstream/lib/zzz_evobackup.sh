#!/usr/bin/env bash
#
# Evobackup client
# See https://gitea.evolix.org/evolix/evobackup
#
# This is a generated backup script made by:
#   command: @COMMAND@
#   version: @VERSION@
#   date:    @DATE@

#######################################################################
#
# You must configure the MAIL variable to receive notifications.
#
# There is some optional configuration that you can do
# at the end of this script.
#
#######################################################################

# Email adress for notifications
MAIL=__NOTIFICATION_MAIL__

#######################################################################
#
# The "sync_tasks" function will be called by the "run_evobackup" function. 
#
# You can customize the variables:
# * "SYNC_NAME"      (String)
# * "SERVERS"        (Array of HOST:PORT)
# * "RSYNC_INCLUDES" (Array of paths to include)
# * "RSYNC_EXCLUDES" (Array of paths to exclude)
#
# WARNING: remember to single-quote paths if they contain globs (*)
# and you want to pass them as-is to Rsync.
#
# The "sync" function can be called multiple times
# with a different set of variables.
# That way you can to sync to various destinations.
#
# Default includes/excludes are defined in the "main" library,
# referenced at this end of this file.
#
#######################################################################

# shellcheck disable=SC2034
sync_tasks() {

    ########## System-only backup (to Evolix servers) #################

    SYNC_NAME="evolix-system"
    SERVERS=(
        __SRV0_HOST__:__SRV0_PORT__
        __SRV1_HOST__:__SRV1_PORT__
    )
    RSYNC_INCLUDES=(
        "${rsync_default_includes[@]}"
        /etc
        /root
        /var
    )
    RSYNC_EXCLUDES=(
        "${rsync_default_excludes[@]}"
    )
    sync "${SYNC_NAME}" "SERVERS[@]" "RSYNC_INCLUDES[@]" "RSYNC_EXCLUDES[@]"


    ########## Full backup (to client servers) ########################

    ### SYNC_NAME="client-full"
    ### SERVERS=(
    ###     client-backup00.evolix.net:2221
    ###     client-backup01.evolix.net:2221
    ### )
    ### RSYNC_INCLUDES=(
    ###     "${rsync_default_includes[@]}"
    ###     /etc
    ###     /root
    ###     /var
    ###     /home
    ###     /srv
    ### )
    ### RSYNC_EXCLUDES=(
    ###     "${rsync_default_excludes[@]}"
    ### )
    ### sync "${SYNC_NAME}" "SERVERS[@]" "RSYNC_INCLUDES[@]" "RSYNC_EXCLUDES[@]"

}

#######################################################################
#
# The "local_tasks" function will be called by the "run_evobackup" function. 
#
# You can call any available "dump_xxx" function
# (usually installed at /usr/local/lib/evobackup/dump-*.sh)
#
# You can also write some custom functions and call them.
# A "dump_custom" example is available further down.
#
#######################################################################

local_tasks() {

    ########## Server state ###########

    # Run dump-server-state to extract system information
    #
    # Options : any dump-server-state supported option
    # (except --dump-dir that will be overwritten)
    # See 'dump-server-state -h' for details.
    #
    dump_server_state

    ########## MySQL ##################

    # Very common strategy for a single instance server with default configuration :
    #
    ### dump_mysql_global; dump_mysql_grants; dump_mysql_summary
    #
    # See below for details regarding dump functions for MySQL/MariaDB
 
    # Dump all databases in a single compressed file
    #
    # Options :
    #   --masterdata (default: <absent>)
    #   --port=[Integer] (default: <blank>)
    #   --socket=[String] (default: <blank>)
    #   --user=[String] (default: <blank>)
    #   --password=[String] (default: <blank>)
    #   --defaults-file=[String] (default: <blank>)
    #   --defaults-extra-file=[String] (default: <blank>)
    #   --defaults-group-suffix=[String] (default: <blank>)
    #   --dump-label=[String] (default: "default")
    #     used as suffix of the dump dir to differenciate multiple instances
    #
    ### dump_mysql_global
    
    # Dump each database separately, in a compressed file
    #
    # Options :
    #   --port=[Integer] (default: <blank>)
    #   --socket=[String] (default: <blank>)
    #   --user=[String] (default: <blank>)
    #   --password=[String] (default: <blank>)
    #   --defaults-file=[String] (default: <blank>)
    #   --defaults-extra-file=[String] (default: <blank>)
    #   --defaults-group-suffix=[String] (default: <blank>)
    #   --dump-label=[String] (default: "default")
    #     used as suffix of the dump dir to differenciate multiple instances
    #
    ### dump_mysql_per_base

    # Dump permissions of an instance (using pt-show-grants)
    #
    # Options :
    #   --port=[Integer] (default: <blank>)
    #   --socket=[String] (default: <blank>)
    #   --user=[String] (default: <blank>)
    #   --password=[String] (default: <blank>)
    #   --defaults-file=[String] (default: <blank>)
    #   --dump-label=[String] (default: "default")
    #     used as suffix of the dump dir to differenciate multiple instances
    #
    # WARNING - unsupported options :
    #   --defaults-extra-file
    #   --defaults-group-suffix
    # You have to provide credentials manually
    #
    ### dump_mysql_grants

    # Dump complete summary of an instance (using pt-mysql-summary)
    #
    # Options :
    #   --port=[Integer] (default: <blank>)
    #   --socket=[String] (default: <blank>)
    #   --user=[String] (default: <blank>)
    #   --password=[String] (default: <blank>)
    #   --defaults-file=[String] (default: <blank>)
    #   --defaults-extra-file=[String] (default: <blank>)
    #   --defaults-group-suffix=[String] (default: <blank>)
    #   --dump-label=[String] (default: "default")
    #     used as suffix of the dump dir to differenciate multiple instances
    #
    ### dump_mysql_summary

    # Dump each table in separate schema/data files
    #
    # Options :
    #   --port=[Integer] (default: <blank>)
    #   --socket=[String] (default: <blank>)
    #   --user=[String] (default: <blank>)
    #   --password=[String] (default: <blank>)
    #   --defaults-file=[String] (default: <blank>)
    #   --defaults-extra-file=[String] (default: <blank>)
    #   --defaults-group-suffix=[String] (default: <blank>)
    #   --dump-label=[String] (default: "default")
    #     used as suffix of the dump dir to differenciate multiple instances
    #
    ### dump_mysql_tabs

    ########## PostgreSQL #############

    # Dump all databases in a single file (compressed or not)
    #
    ### dump_postgresql_global

    # Dump a specific databse with only some tables, or all but some tables (must be configured)
    #
    ### dump_postgresql_filtered

    # Dump each database separately, in a compressed file
    #
    ### dump_postgresql_per_base

    ########## MongoDB ################
    
    ### dump_mongodb [--user=foo] [--password=123456789]

    ########## Redis ##################

    # Copy data file for all instances
    #
    # The instance name is the config directory name
    # eg. "redis" for "/etc/redis/", "redis-foo" for "/etc/redis-foo"
    ### dump_redis [--instances=<all|instance1,instance2>]

    ########## Elasticsearch ##########

    # Snapshot data for a single-node cluster
    #
    ### dump_elasticsearch_snapshot_singlenode [--protocol=http] [--host=localhost] [--port=9200] [--user=foo] [--password=123456789] [--repository=snaprepo] [--snapshot=snapshot.daily]

    # Snapshot data for a multi-node cluster
    #
    ### dump_elasticsearch_snapshot_multinode [--protocol=http] [--host=localhost] [--port=9200] [--user=foo] [--password=123456789] [--repository=snaprepo] [--snapshot=snapshot.daily] [--nfs-server=192.168.2.1]

    ########## RabbitMQ ###############

    ### dump_rabbitmq

    ########## MegaCli ################

    # Copy RAID config
    #
    ### dump_megacli_config

    # Dump file access control lists
    #
    ### dump_facl

    ########## OpenLDAP ###############

    ### dump_ldap

    ########## Network ################

    # Dump network routes with mtr and traceroute (warning: could be long with aggressive firewalls)
    #
    ### dump_traceroute --targets=host_or_ip[,host_or_ip]
    dump_traceroute --targets=8.8.8.8,www.evolix.fr,travaux.evolix.net

    # No-op, in case nothing is enabled
    :
}

# This is an example for a custom dump function
# Uncomment, customize and call it from the "local_tasks" function
### dump_custom() {
###     # Set dump and errors directories and files
###     local dump_dir="${LOCAL_BACKUP_DIR}/custom"
###     local dump_file="${dump_dir}/dump.gz"
###     local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
###     local error_file="${errors_dir}/dump.err"
### 
###     # Reset dump and errors directories
###     rm -rf "${dump_dir}" "${errors_dir}"
###     # shellcheck disable=SC2174
###     mkdir -p -m 700 "${dump_dir}" "${errors_dir}"
###
###     # Log the start of the function
###     log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"
###
###     # Prepare the dump command (errors go to the error file and the data to the dump file)
###     dump_cmd="my-dump-command 2> ${error_file} > ${dump_file}"
###     log "LOCAL_TASKS - ${FUNCNAME[0]}: ${dump_cmd}"
### 
###     # Execute the dump command
###     ${dump_cmd}
###
###     # Check result and deal with potential errors
###     local last_rc=$?
###     # shellcheck disable=SC2086
###     if [ ${last_rc} -ne 0 ]; then
###         log_error "LOCAL_TASKS - ${FUNCNAME[0]}: my-dump-command to ${dump_file} returned an error ${last_rc}" "${error_file}"
###         GLOBAL_RC=${E_DUMPFAILED}
###     else
###         rm -f "${error_file}"
###     fi
###
###     # Log the end of the function
###     log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
### }

########## Optional configuration #####################################

setup_custom() {
    # System name ("linux" and "openbsd" currently supported)
    ### SYSTEM="$(uname)"

    # Host name for logs and notifications
    ### HOSTNAME="$(hostname)"

    # Email subject for notifications
    ### MAIL_SUBJECT="[info] EvoBackup - Client ${HOSTNAME}"

    # No-op in case nothing is executed
    :
}

########## Libraries ##################################################

# Change this to wherever you install the libraries
LIBDIR="/usr/local/lib/evobackup"

source "${LIBDIR}/main.sh"

########## Let's go! ##################################################

run_evobackup
