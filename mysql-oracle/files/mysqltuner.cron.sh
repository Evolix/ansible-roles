#!/bin/bash
set -e
export TERM=screen

mem=$(free -m | grep Mem: | tr -s ' ' | cut -d ' ' -f2)
swap=$(free -m | grep Swap: | tr -s ' ' | cut -d ' ' -f2)
template=$(mktemp --tmpdir=/tmp evomysqltuner.XXX)
body=$(mktemp --tmpdir=/tmp evomysqltuner.XXX)
clientmail=$(grep EVOMAINTMAIL /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=$(grep HOSTNAME /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
# If hostname is composed with -, remove the first part.
if [[ $hostname =~ "-" ]]; then
    hostname=$(echo $hostname | cut -d'-' -f2-)
fi

# Remove temporary files on exit.
trap "rm $template $body" EXIT

# Add port here if you have more than one instance!
instances="3306"
for instance in $instances; do
    mysqltuner --port $instance --host 127.0.0.1 --forcemem $mem --forceswap $swap \
      | aha > /var/www/mysqlreport_${instance}.html
    cat << EOT > $template
Content-Type: text/plain; charset="utf-8"
Reply-To: Équipe Evolix <equipe@evolix.fr>
From: Équipe Evolix <equipe@evolix.net>
To: $clientmail
Subject: Rapport MySQL instance $instance pour votre serveur $hostname
EOT
    cat << EOT > $body
Bonjour,

Veuillez trouver ci-joint un rapport MySQL.
Celui-ci permet d'identifier aisément si des optimisations MySQL sont possibles.

N'hésitez pas à nous indiquer par mail ou ticket quelles variables vous souhaiter
optimiser.

Veuillez noter qu'il faudra redémarrer MySQL pour appliquer de nouveaux paramètres.

Bien à vous,
--
Rapport automatique Evolix
EOT
    mutt -x -e 'set send_charset="utf-8"' -e "set crypt_use_gpgme=no" -H $template \
      -a /var/www/mysqlreport_${instance}.html < $body
done
chmod 644 /var/www/mysqlreport*html
