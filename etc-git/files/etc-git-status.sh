#!/bin/bash
set -e
export TERM=screen
export LC_ALL=C

hostname=$(grep HOSTNAME /etc/evomaintenance.cf | cut -d'=' -f2)
hostname=${hostname%%.evolix.net}
template=$(mktemp --tmpdir=/tmp etc-git-status.XXX)
body=$(mktemp --tmpdir=/tmp etc-git-status.XXX)
lastLogOutput=$(mktemp --tmpdir=/tmp etc-git-status.XXX)
gitOutput=$(mktemp --tmpdir=/tmp etc-git-status.XXX)
lastTime=7
uidRange="2000-2099"

# Remove temporary files on exit
trap "rm $lastLogOutput" EXIT

# Get last admins connected
lastlog -t $lastTime -u $uidRange > $lastLogOutput

# Add these admins to an array if there are
lastLogOutputCount=$(wc -l $lastLogOutput | awk '{ print $1 }')
if [ $lastLogOutputCount -gt 1 ]; then
    while read line; do
        user=$(awk '{ print $1 }' <<< $line)
        if [ $user != "Username" ]; then
            lastAdmins="$lastAdmins${user}@evolix.fr, "
        fi
    done < $lastLogOutput
else
    lastAdmins="$lastAdmins"
fi

# Send the mail
git --git-dir=/etc/.git --work-tree=/etc status --short > $gitOutput
if [ $gitOuput -n ]; then
    cat << EOT > $template
Content-Type: text/plain; charset="utf-8"
Reply-To: Équipe Evolix <equipe@evolix.fr>
From: Équipe Evolix <equipe@evolix.net>
To: $lastAdmins
Subject: Non commited /etc for server $hostname
EOT
    cat << EOT > $body
Dear ${lastAdmins}

As you were connected on $hostname in the last 7 days, please commit modifications on /etc.
You should use evomaintenance for that.

git status:

$(<$gitOutput)

--
etc-git-status.sh
EOT
    mutt -x -e 'set send_charset="utf-8"' -H $template < $body
fi
