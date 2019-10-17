#!/bin/sh
#
# Manage MySQL accounts and databases.
#
# Note: in the following code:
#   - account means user@host
#   - user is the user part of account
#

MYSQL_OPTS="--raw --skip-column-names --skip-line-numbers"

usage() {
    cat <<EOT >&2
Usage: $0 <command> [<command arg>]

Available commands are:

    list [<user>]
    List all accounts and their databases, separated by semi-colon. If user
    is specified, list databases for this user only.

    passwd <user> <new password>
    Change password for specified user.

EOT
}

error() {
    printf >&2 "Error: $@\n"
}

get_host() {
    user="$1"
    host=$(mysql $MYSQL_OPTS --execute "SELECT host FROM mysql.user WHERE user='$user'")
    if [ $(echo "$host" |wc -l) -gt 1 ]; then
        # TODO: Not perfect!
        echo "$host" |grep '%'
    else
        echo $host
    fi
}

get_dbs() {
    account="$1"
    echo "$(mysql $MYSQL_OPTS --execute "SHOW GRANTS FOR $account" |perl -ne 'print "$1 " if (/^GRANT (?!USAGE).* ON `(.*)`/)')"
}

get_accounts() {
    echo "$(mysql $MYSQL_OPTS --execute "SELECT user,host FROM mysql.user;" |perl -ne 'print "$1\@$2\n" if (/^([^\s]+)\s+([^\s]+)$/)'|sed "s/^/'/; s/@/'@'/; s/$/'/;")"
}

list() {
    if [ $# -gt 0 ]; then
        user="$1"
        host=$(get_host $user)
        account="'$user'@'$host'"
        echo $account:$(get_dbs "$account")
    else
        for account in $(get_accounts); do
            echo $account:$(get_dbs "$account")
        done
    fi
}

passwd() {
    if [ $# -ne 2 ]; then
        usage
        exit 1
    fi

    user="$1"
    password="$2"
    host=$(get_host $user)

    mysql -e "SET PASSWORD FOR '$user'@'$host' = PASSWORD('$password');"
}


#
# Argument processing.
#

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

command="$1"
shift

case "$command" in 
    list)
        list $@
        ;;
    passwd)
        passwd $@
        ;;
    *)
        error "Unknown command: $command."
        ;;
esac
