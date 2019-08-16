#!/bin/bash

set -e

configFile="/etc/evolinux/newkernel.cnf"

template=$(mktemp --tmpdir=/tmp evoupdate.XXX)
clientmail=$(grep EVOMAINTMAIL /etc/evomaintenance.cf | cut -d'=' -f2)
mailto=$clientmail
date="Ce jeudi entre 18h00 et 23h00."
hostname=$(grep HOSTNAME /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
# If hostname is composed with -, remove the first part.
if [[ $hostname =~ "-" ]]; then
    hostname=$(echo $hostname | cut -d'-' -f2-)
fi
# Edit $configFile to override some variables.
[ -r $configFile ] && . $configFile

# Remove temporary files on exit.
trap "rm $template" EXIT

# No updates? Exit!
nextKernel=$(grep -m1 -aEo "#1 SMP Debian .* \([0-9]{4}-[0-9]{2}-[0-9]{2}\)" /vmlinuz)
currentKernel=$(uname -v)
if [ "$nextKernel" = "$currentKernel" ]; then
    exit 0
fi

#To: ${clientmail}
cat << EOT > $template
Content-Type: text/plain; charset="utf-8"
Reply-To: equipe@evolix.fr
From: equipe@evolix.net
To: bserie@evolix.fr
Subject: Prochain creneau pour mise a jour de votre serveur $hostname
X-Date: $date

Bonjour,

Le noyau de votre serveur doit être mis à jour. Pour cela nous devons
redémarrer votre machine ${hostname}.

Sauf indication contraire de votre part,
le prochain créneau prévu pour
intervenir manuellement pour réaliser ces mises-à-jour est :
${date}

Si nous intervenons, un redémarrage complet du serveur sera réalisé, entraînant
plusieurs minutes de coupures. Nous nous assurerons de vérifier le bon
démarrage de la machin ainsi que de ses services.  Si nous ne sommes pas
intervenus sur ce créneau, vous recevrez une nouvelle notification le mois
prochain.

Votre version actuelle du noyau : $currentKernel
Après redémarrage votre version sera : $nextKernel

N'hésitez pas à nous faire toute remarque sur ce créneau d'intervention le plus
tôt possible.

Cordialement,
-- 
Équipe Evolix <equipe@evolix.fr>
Evolix - Hébergement et Infogérance Open Source http://www.evolix.fr/
EOT

<$template /usr/sbin/sendmail $mailto