#!/bin/sh

usage() {
    echo "Usage: $0 [ -d <database> -u <user> [-p <password>] [-f] ]"
}

if [ $# = 0 ]; then
    is_interactive="true"
    echo "Add an account / database in MySQL"
    echo "Enter the name of the new database"
    read db

    echo "Enter account with all right on this new database"
    echo "(you can use existant account)"
    read user
else
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
fi

is_db=$(mysql mysql -Ne "SELECT COUNT(Db) FROM db WHERE Db='${db}';")
if [ $is_db -gt 0 ]; then
    echo "Database $db already exist !" >&2
    exit 1
fi

is_user=$(mysql mysql -Ne "SELECT COUNT(User) from user WHERE User='${user}';")
if [ $is_user -gt 0 ]; then
    if [ -n ${is_interactive} ]; then
        echo "Warning, account already exists, update password ? [N/y]"
        read confirm
        if [ "${confirm}" = "y" ] || [ "${confirm}" = "Y" ]; then
            force="update"
            echo -n "Enter new password for existant MySQL account (empty for random): "
            read password
        fi
    else
        if [ -z "${force}" ]; then
            if [ -n "${password}" ]; then
                echo "User $user already exist, update password with -f !" >&2
                exit 1
            fi
        else
            force="update"
        fi
    fi
else
    echo -n "Enter new password for new MySQL account (empty for random): "
    read password
    echo ""

fi

if [ -z "${password}" ]; then
    password=$(apg -n1)
    random="yes"
fi

if [ -z "${force}" ]; then

mysql << END_SCRIPT
    CREATE DATABASE \`${db}\`;
    GRANT ALL PRIVILEGES ON \`${db}\`.* TO \`${user}\`@localhost;
    FLUSH PRIVILEGES;
END_SCRIPT

    if [ $? = 0 ]; then
        if [ $is_user -gt 0 ]; then
            echo "Database ${db} created"
        else
            echo "User ${user} and database ${db} created"
        fi
    fi

else

mysql << END_SCRIPT
    CREATE DATABASE \`${db}\`;
    GRANT ALL PRIVILEGES ON \`${db}\`.* TO \`${user}\`@localhost IDENTIFIED BY "${password}";
    FLUSH PRIVILEGES;
END_SCRIPT

    if [ $? = 0 ]; then
        echo "Database ${db} created and password of ${user} updated"
    fi

fi

if [ -n "${random}" ]; then
    echo "Password : ${password}"
fi
