#!/bin/sh

# timestamp modulo 1 day.
time=$(($(date +"%s") %86400))

# pour trouver les valeurs : prendre l'heure en *UTC*
# et faire H * 3600 + M * 60 + S
if [ $time -ge 7200 ] && [ $time -lt 10800 ]; then
        echo "In excluded time slot."
        exit 0
else
        $@
        exit $?
fi
