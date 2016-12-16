#!/bin/sh

echo "Add an account / database in MySQL"
echo "Enter the name of the new database"
read db

echo "Enter account with all right on this new database"
echo "(you can use existant account)"
read login

echo -n "Does this account already exist ? [y|N] "
read confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
echo "Warning, if account exists, it will be reset !"
echo -n "Enter new password for new MySQL account (empty for random): "
read -s password
echo ""

length=${#password}

if [ -n $password ]; then
    password=$(apg -n1 -E FollyonWek7)
    echo "New password: $password"
fi

mysql << END_SCRIPT
    CREATE DATABASE \`$db\`;
    GRANT ALL PRIVILEGES ON \`$db\`.* TO \`$login\`@localhost IDENTIFIED BY "$password";
    FLUSH PRIVILEGES;
END_SCRIPT

else

mysql << END_SCRIPT
    CREATE DATABASE \`$db\`;
    GRANT ALL PRIVILEGES ON \`$db\`.* TO \`$login\`@localhost;
    FLUSH PRIVILEGES;
END_SCRIPT

fi

echo "If no error, new database $db is OK"
