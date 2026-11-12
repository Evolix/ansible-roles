#!/bin/sh

# Variables

version="26.11.2"
hostname=$(hostname)
replication_ids=$(pvesh get "/nodes/${hostname}/replication/" --noheader --noborder --output-format json | jq '.[].id' | tr -d '"')
time_crit="7200"
return_code="0"

# Functions

show_version() {
    cat <<END
pve_replication version ${version}

Copyright 2004-2026 Evolix <info@evolix.fr>,
                    Éric Morino <emorino@evolix.fr>,
                    and other.

pve_replication comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU Affero General Public License v3.0 for details.
END
}

help()
{
   # Display Help
   echo "Nrpe check for Proxmox Virtual Environnment replication"
   echo "check time is 7200 second by defaults, add threshold value with -c argument"
   echo
   echo "Syntax: [-h|c|V]"
   echo "options:"
   echo "h     Print this Help."
   echo "c     Add time critical threshold."
   echo "V     Print software version and exit."
   echo
}

# Options

while getopts "hVc:" option; do
   case ${option} in
      h) # display Help
         help
         exit;;
      c) # Check time threshold value 
         time_crit=$OPTARG;;
      V) # display version
         show_version
         exit;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

# Main program

for replication_id in ${replication_ids}; do
    last_sync=$(pvesh get "/nodes/${hostname}/replication/${replication_id}/status" --noheader --noborder | grep -E "last_sync" | awk '{ print $2 }')
    time_now=$(date +"%s")
    time_delta=$(( time_now - last_sync ))
    if [ "${time_delta}" -lt "${time_crit}" ]; then
        echo " OK : Last sync: VM $replication_id as $time_delta seconds ago"
    else
        echo "Error : Last sync: VM $replication_id as $time_delta seconds ago"
        pvesh get "/nodes/${hostname}/replication/${replication_id}/log" --noheader --noborder | tail -n 2
        return_code=2
    fi
done

exit ${return_code}
