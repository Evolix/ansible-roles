#!/bin/sh

# This script verifies if the specified partitions on a machine are filled
# at more than x%.
#
# If so, it sends a mail to the admin of that machine, warning him/her
# that mesures should be taken.
#
# Two outputs are provided to the recipient of the mail:
#  * some general infos with `df`
#  * a more indepth inspection with `duc`
#
# This script takes 3 (mandatory) arguments:
#  * a list of the partitions to check (space separated)
#  * the maximum allowed percentage
#  * the email template to use
# 
# This script should be ran by cron @daily.
#
#
# Copyright (C) 2016 Louis-Philippe Véronneau <lpveronneau@evolix.ca, Evolix <info@evolix.fr>
#
# This program is licensed under GPLv3 +


# Check argument sanity

PID_FILE='/var/run/check_free_space.pid'

if test -f "$PID_FILE"
then
  pid=$(cat "$PID_FILE")
  ps -p "$pid" > /dev/null
  if test $? -eq 0
  then
    echo "$0 already run !" >&2
    exit 1
  else
    rm $PID_FILE
  fi
fi

echo $$ > $PID_FILE

if test -z "$1" || test -z "$2" || test -z "$3"  # is non null
then
  echo "Some arguments are missing. Please issue a partition list, a" \
       "maximum percentage and an email template."
  exit 1
elif ! [ "$2" -le 100 -a "$2" -ge 0 ] # is a percentage
then
  echo "Please enter a maximum percentage value between 0 and 100."
  exit 1
fi

# Argument processing

partition_list=$1
max_percentage=$((100-$2))
email_template=$3

HOSTNAME=$(hostname)
debian_version=$(lsb_release -c)

check_disk='/usr/lib/nagios/plugins/check_disk'

test -f /etc/evomaintenance.cf && . /etc/evomaintenance.cf


# Test what version of df we have

old_df=false

case "$debian_version" in
    *squeeze* ) old_df=true ;;
    *wheezy* ) old_df=true ;;
esac


# Check disk space

df_options="size,avail,pcent,itotal,iavail,ipcent"

for partition in $partition_list
do
  if ! $check_disk -w $max_percentage% -W $max_percentage% $partition > /dev/null
  then
    # the 'newline' is a hack to make sed behave
    PARTITION_DATA="$PARTITION_DATA newline $partition newline"
    if [ $old_df ]
    then
      PARTITION_DATA="$PARTITION_DATA $(/bin/df -h $partition) newline"
      PARTITION_DATA="$PARTITION_DATA newline $(df -ih $partition) newlinenewline"
    else
      PARTITION_DATA="$PARTITION_DATA $(/bin/df -h --output=$df_options $partition) newline"
    fi
    full_partitions="$full_partitions $partition"
    partname=$(echo $partition|tr -s '/' '-')
    graph_list="$graph_list -a /home/duc${partname}.png"
  fi
done


# Exit if everything is OK

if test -z "$PARTITION_DATA"
then
  exit 0
fi
 

# If there is indeed a problem, get more infos with duc

/usr/bin/ionice -c3 /usr/bin/duc index -H -d /home/duc.idx -x $full_partitions -q

for partition in $full_partitions
do
  duc_temp=$(/usr/bin/duc ls -d /home/duc.idx -Fg $partition)
  duc_temp=$(printf "$duc_temp" | sed -e "s@]@]newline@" | grep -v "lost+found")
  DUC_OUTPUT="$DUC_OUTPUT newline$partition newline$duc_temp"
  partname=$(echo $partition|tr -s '/' '-')
  duc graph -d /home/duc.idx -o /home/duc${partname}.png -l8 -s 1024 $partition
done 


# Replace placeholders & send the mail !

PARTITION_DATA="$(echo "$PARTITION_DATA"|tr -d $'\n')" # make sed accept the input
DUC_OUTPUT="$(echo "$DUC_OUTPUT"|tr -d $'\n')"

if [ $old_df ]
then
  sed -e "s/__TO__/$EVOMAINTMAIL/"                         \
      -e "s/__HOSTNAME__/$HOSTNAME/"                       \
      -e "s@__PARTITION_DATA__@$PARTITION_DATA@"           \
      -e "s@__DUC_OUTPUT__@$DUC_OUTPUT@"                   \
      -e "s/newline/\n/g"                                  \
      -e "s/IUse%/IUse%\n/g"                               \
      -e "s/ Use%/ Use%\n/g"                               \
      -e "s@Filesystem \{12\}@@g"                          \
      -e "s@Mounted on\/dev\/[a-z]\{3\}[0-9]\+ \{13\}@@g"  \
      -e "s@% \/[a-z]\+@%@g"                               \
      -e "s/__MAX_PERCENTAGE__/$max_percentage/"           \
      -e "s/__FULLFROM__/$FULLFROM/"                       \
      -e "s/__FROM__/$FROM/"                               \
      -e "s/__URGENCYFROM__/$URGENCYFROM/"                 \
      -e "s/__URGENCYTEL__/$URGENCYTEL/"                   \
       $email_template |                                   \
  /usr/bin/mutt -H - $graph_list
else
  sed -e "s/__TO__/$EVOMAINTMAIL/"               \
      -e "s/__HOSTNAME__/$HOSTNAME/"             \
      -e "s@__PARTITION_DATA__@$PARTITION_DATA@" \
      -e "s@__DUC_OUTPUT__@$DUC_OUTPUT@"         \
      -e "s/newline/\n/g"                        \
      -e "s/IUse%/IUse%\n/g"                     \
      -e "s/__MAX_PERCENTAGE__/$max_percentage/" \
      -e "s/__FULLFROM__/$FULLFROM/"             \
      -e "s/__FROM__/$FROM/"                     \
      -e "s/__URGENCYFROM__/$URGENCYFROM/"       \
      -e "s/__URGENCYTEL__/$URGENCYTEL/"         \
       $email_template |                         \
  /usr/bin/mutt -H - $graph_list
fi

rm -f $PID_FILE
