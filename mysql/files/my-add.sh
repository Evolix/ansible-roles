#!/bin/sh

usage() {
    echo "Usage: $0 [ -d <database> -u <user> [-p <password>] [-f] ]"
}

interactive() {
    echo "Add an account / database in MySQL"
    echo "Enter the name of the new database"
    read db

    if ( is_db $db ); then
        echo "Database $db already exist !" >&2
        exit 1
    fi

    echo "Enter account with all right on this new database"
    echo "(you can use existant account)"
    read user

    if ( is_user $user ); then
        echo "Warning, account already exists, update password ? [N/y]"
        read confirm
        if [ "${confirm}" = "y" ] || [ "${confirm}" = "Y" ]; then
            echo -n "Enter new password for existant MySQL account (empty for random): "
            read password
            if [ -z "${password}" ]; then
                password=$(apg -n1)
            fi
        fi
    else
        echo -n "Enter new password for new MySQL account (empty for random): "
        read password
        if [ -z "${password}" ]; then
                password=$(apg -n1)
        fi
    fi
    mysql_add $db $user $password
}

cli() {
    while getopts ":d:u:p:f" opt; do
        case "$opt" in
        d)
                db=$OPTARG
                ;;
            u)
                user=$OPTARG
                ;;
            p)
                password=$OPTARG
                ;;
            f)
                force="true"
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
    shift $((OPTIND-1))
    
    if [ -z "${db}" ]; then
        usage
        exit 1
    fi
    
    if [ -z "${user}" ]; then
        usage
        exit 1
    fi

    if ( is_db $db ); then
        echo "Database $db already exist !" >&2
        exit 1
    fi
    
    if ( is_user $user ); then
        if [ -z "${force}" ]; then
            if [ -n "${password}" ]; then
                echo "User $user already exist, update password with -f !" >&2
                exit 1
            fi
        else
            if [ -z "${password}" ]; then
                password=$(apg -n1)
            fi
        fi
    else
        if [ -z "${password}" ]; then
            password=$(apg -n1)
        fi
    fi
    mysql_add $db $user $password
}

is_db() {
    db=$1
    mysql mysql -Ne "SHOW DATABASES;"|grep -q "^${db}$"
    exit $?
}

is_user() {
    user=$1
    nb_user=$(mysql mysql -Ne "SELECT COUNT(User) from user WHERE User='${user}';")
    if [ $nb_user -gt 0 ]; then
        exit 0
    else
        exit 1
    fi
}

mysql_add() {
    db=$1
    user=$2
    password=$3

    echo -n "Create '${db}' database ..."
    mysql -e "CREATE DATABASE ${db};"
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        echo "KO"
        exit 1
    fi
    if [ -z "${password}" ]; then
        echo -n "Grant '${user}' to '${db}' database ..."
        mysql -e "GRANT ALL PRIVILEGES ON ${db}.* TO ${user}@localhost;"
        grant=$?
    else
        echo -n "Grant '${user}' to '${db}' database with password '${password}' ..."
        mysql -e "GRANT ALL PRIVILEGES ON ${db}.* TO ${user}@localhost IDENTIFIED BY '${password}';"
        grant=$?
    fi
    if [ $grant -eq 0 ]; then
        echo "OK"
    else
        echo "KO"
        exit 1
    fi
    echo -n "Flush Mysql privileges ..."
    mysql -e "FLUSH PRIVILEGES;"
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        echo "KO"
        exit 1
    fi
}

main() {
    if [ $# = 0 ]; then
        interactive
    else
        cli $@
    fi
}
main $@
