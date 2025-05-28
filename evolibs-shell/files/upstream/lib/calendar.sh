#!/bin/bash

#######################################################################
# This set of functions helps determining if the current day or time
# is special, regarding our monitoring configuration.
#######################################################################
#
# Copyright 2009-2025 Evolix <info@evolix.fr>,
#                     Jérémy Lecour <jlecour@evolix.fr>,
#                     and others.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#######################################################################

evo::os-release::version() {
    local VERSION="1.0.0"
    
    echo "${VERSION}"
}

#######################################
# Tells if the current day is a holiday in France
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   0 if true, 1 if false
#######################################
evo::calendar::is_holiday() {
    if ! command -v gcal >/dev/null; then
        >&2 echo "gcal: command not found"
        exit 2
    fi

    # gcal mark today as a holiday by surrounding with < and > the day
    # of the month of that holiday line.  For example if today is 2022-05-01 we'll
    # get among other lines:
    # Fête du Travail (FR)                    + Di, < 1>Mai 2022
    # Jour de la Victoire (FR)                + Di, : 8:Mai 2022 =   +7 jours

    if LANGUAGE=fr_FR.UTF-8 TZ=Europe/Paris gcal --cc-holidays=fr --holiday-list=short \
        | grep --quiet --extended-regexp '<[0-9 ]{2}>'; then
        return 0
    else
        return 1
    fi
}

#######################################
# Tells if the current day is during the weekend (saturday/sunday)
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   0 if true, 1 if false
#######################################
evo::calendar::is_weekend() {
    day_of_week=$( date +%u )
    if [ "${day_of_week}" != 6 ] && [ "${day_of_week}" != 7 ]; then
        return 1
    fi

    return 0
}

#######################################
# Tells if the current day is a working day (monday-friday, not holiday)
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   0 if true, 1 if false
#######################################
evo::calendar::is_workday() {
    if evo::calendar::is_holiday || evo::calendar::is_weekend; then
        return 1
    fi

    return 0
}

#######################################
# Tells if the current time is during working hours (workday 09h-12h + 14h-18h)
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   0 if true, 1 if false
#######################################
evo::calendar::is_worktime() {
    if ! evo::calendar::is_workday; then
        return 1
    fi

    hour=$( date +%H )
    if [ "${hour}" -lt 9 ] || { [ "${hour}" -ge 12 ] && [ "${hour}" -lt 14 ] ; } || [ "${hour}" -ge 18 ]; then
        return 1
    fi

    return 0
}
