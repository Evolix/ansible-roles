#!/bin/ksh

################################################################################
# Sample Nagios plugin to monitor free memory on the local machine             #
# Author: Daniele Mazzocchio (http://www.kernel-panic.it/)                     #
################################################################################

VERSION="Version 1.0"
AUTHOR="(c) 2007-2009 Daniele Mazzocchio (danix@kernel-panic.it)"

PROGNAME=`/usr/bin/basename $0`

# Constants
BYTES_IN_MB=$(( 1024 * 1024 ))
KB_IN_MB=1024

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Helper functions #############################################################

function print_revision {
   # Print the revision number
   echo "$PROGNAME - $VERSION"
}

function print_usage {
   # Print a short usage statement
   echo "Usage: $PROGNAME [-v] -w <limit> -c <limit>"
}

function print_help {
   # Print detailed help information
   print_revision
   echo "$AUTHOR\n\nCheck free memory on local machine\n"
   print_usage

   /bin/cat <<__EOT

Options:
-h
   Print detailed help screen
-V
   Print version information

-w INTEGER
   Exit with WARNING status if less than INTEGER MB of memory are free
-w PERCENT%
   Exit with WARNING status if less than PERCENT of memory is free
-c INTEGER
   Exit with CRITICAL status if less than INTEGER MB of memory are free
-c PERCENT%
   Exit with CRITICAL status if less than PERCENT of memory is free
-v
   Verbose output
__EOT
}

# Main #########################################################################

# Total memory size (in MB)
tot_mem=$(( `/sbin/sysctl -n hw.physmem` / BYTES_IN_MB))
# Free memory size (in MB)
free_mem=$(( `/usr/bin/vmstat | /usr/bin/tail -1 | /usr/bin/awk '{ print $5 }'` / KB_IN_MB ))
# Free memory size (in percentage)
free_mem_perc=$(( free_mem * 100 / tot_mem ))

# Verbosity level
verbosity=0
# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=

# Parse command line options
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -V | --version)
           print_revision
           exit $STATE_OK
           ;;
       -v | --verbose)
           : $(( verbosity++ ))
           shift
           ;;
       -w | --warning | -c | --critical)
           if [[ -z "$2" || "$2" = -* ]]; then
               # Threshold not provided
               echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
           elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is a number (MB)
               thresh=$2
           elif [[ "$2" = +([0-9])% ]]; then
               # Threshold is a percentage
               thresh=$(( tot_mem * ${2%\%} / 100 ))
           else
               # Threshold is neither a number nor a percentage
               echo "$PROGNAME: Threshold must be integer or percentage"
               print_usage
               exit $STATE_UNKNOWN
           fi
           [[ "$1" = *-w* ]] && thresh_warn=$thresh || thresh_crit=$thresh
           shift 2
           ;;
       -?)
           print_usage
           exit $STATE_OK
           ;;
       *)
           echo "$PROGNAME: Invalid option '$1'"
           print_usage
           exit $STATE_UNKNOWN
           ;;
   esac
done

if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
   # One or both thresholds were not specified
   echo "$PROGNAME: Threshold not set"
   print_usage
   exit $STATE_UNKNOWN
elif [[ "$thresh_crit" -gt "$thresh_warn" ]]; then
   # The warning threshold must be greater than the critical threshold
   echo "$PROGNAME: Warning free space should be more than critical free space"
   print_usage
   exit $STATE_UNKNOWN
fi

if [[ "$verbosity" -ge 2 ]]; then
   # Print debugging information
   /bin/cat <<__EOT
Debugging information:
  Warning threshold: $thresh_warn MB
  Critical threshold: $thresh_crit MB
  Verbosity level: $verbosity
  Total memory: $tot_mem MB
  Free memory: $free_mem MB ($free_mem_perc%)
__EOT
fi

if [[ "$free_mem" -lt "$thresh_crit" ]]; then
   # Free memory is less than the critical threshold
   echo "MEMORY CRITICAL - $free_mem_perc% free ($free_mem MB out of $tot_mem MB)"
   exit $STATE_CRITICAL
elif [[ "$free_mem" -lt "$thresh_warn" ]]; then
   # Free memory is less than the warning threshold
   echo "MEMORY WARNING - $free_mem_perc% free ($free_mem MB out of $tot_mem MB)"
   exit $STATE_WARNING
else
   # There's enough free memory!
   echo "MEMORY OK - $free_mem_perc% free ($free_mem MB out of $tot_mem MB)"
   exit $STATE_OK
fi
