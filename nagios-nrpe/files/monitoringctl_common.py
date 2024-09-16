#!/usr/bin/env python3
#
# Common functions for monitoringctl and alerts_wrapper
#
# Source:
#     https://gitea.evolix.org/evolix/ansible-roles/src/branch/stable/nagios-nrpe/

# Dependencies :
# - python3-distro

import sys, os
from datetime import datetime, timezone
import re
import distro
import subprocess

prog_name = os.path.basename(__file__)

# Location of disable files
var_dir = '/var/lib/monitoringctl'

log_file = '/var/log/monitoringctl.log'

nrpe_conf_path = '/etc/nagios/nrpe.cfg'

debian_major_version = int(distro.major_version())

# If no time limit is provided in CLI or found in file, this value is used
default_disabled_time = '1h'

_nrpe_conf_lines = ''  # populated at the end of the file


def error(err_msg):
    print(err_msg, file=sys.stderr)
    exit(1)


def usage_error(err_msg):
    print(err_msg, file=sys.stderr)
    usage_msg='Execute "{} --help" for information on usage.'.format(prog_name)
    print(usage_msg, file=sys.stderr)
    exit(1)


def log(log_msg):
    now = now_iso()
    with open(log_file, 'a') as file:
        line = '{} - {}: {}'.format(now, prog_name, log_msg)
        file.write(line)


def show_version(prog_version):
    msg = '''
{1} version {2}.

Copyright 2018-2024 Evolix <info@evolix.fr>,
                    Jérémy Lecour <jlecour@evolix.fr>
                    and others.

{1} comes with ABSOLUTELY NO WARRANTY.This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
'''.format(prog_name, prog_version)
    print(msg)


# Return False if duration does not follow format: XwXdXhXmXs, XhX, XmX
def filter_duration(duration):
    time_regex='^([0-9]+w)?([0-9]+d)?(([0-9]+h(([0-9]+m?)|([0-9]+m([0-9]+s?)?))?)|(([0-9]+m([0-9]+s?)?)?))?$'
    pattern = re.compile(time_regex)
    match = pattern.fullmatch(duration)
    return match != None


# Convert human writable duration into seconds
def time_to_seconds(duration):
    regex=(r'((?P<weeks>\d+)w)?'
        r'((?P<days>\d+)d)?'
        r'((?P<hours>\d+)h)?'
        r'((?P<minutes>\d+)(m?$|m))?'
        r'((?P<seconds>\d+)(s?$|s))?'
    )
    pattern = re.compile(regex, re.IGNORECASE)
    m = pattern.match(duration)
    if not m:
        error('Invalid duration: "{}".'.format(duration))

    duration_dict = {}
    for s in ['weeks', 'days', 'hours', 'minutes', 'seconds']:
        if not m[s]:
            duration_dict[s] = 0
        else:
            duration_dict[s] = int(m[s])
    duration_secs = duration_dict['weeks'] * 604800 + duration_dict['days'] * 86400 + duration_dict['hours'] * 3600 + duration_dict['minutes'] * 60 + duration_dict['seconds']
    return duration_secs


# Print re-enable time in secs
def get_enable_time(wrapper_name):
    enable_secs = now_secs()

    disable_file_path = get_disable_file_path(wrapper_name)
    if not os.path.exists(disable_file_path):
        return enable_secs

    with open(disable_file_path, 'r') as file:
        pattern = re.compile('^[0-9]+$')
        for line in file:
            match = pattern.fullmatch(line.strip())
            if match:
                enable_secs = int(line.strip())
                break

    # If disable_file_path is empty, use last change date plus default disabled time
    if not enable_secs:
        file_last_change_secs = int(os.stat(disable_file_path).st_ctime) # stat -c %Z
        default_disabled_time_secs = time_to_seconds(default_disabled_time)
        enable_secs = file_last_change_secs + default_disabled_time_secs

    return enable_secs


# Return disable message
def get_disable_message(wrapper_name):
    disable_file_path = get_disable_file_path(wrapper_name)

    if not os.path.exists(disable_file_path):
        return

    lines = ''
    with open(disable_file_path, 'r') as file:
        lines = file.readlines()
        if len(lines) > 1:
            # Remove first line which contains re-enable time
            # The next lines as the disable message
            lines = lines[1:]
    return ' '.join(lines).replace('\n', '')


def now_secs():
    now_secs = round(datetime.now().timestamp())
    return now_secs


def now_iso():
    dt = datetime.now(timezone.utc).astimezone()
    dt = dt.replace(microsecond=0)
    return dt.isoformat()


# Return delay before re-enable in secs
def calc_enable_delay(reenable_time): # in secs
    return int(reenable_time - now_secs())


# Convert delay (in seconds) into human readable duration
def delay_to_string(delay):
    delay_days = '{}d'.format(delay // 86400)
    if delay_days == '0d': delay_days = ''

    delay_hours = '{}h'.format((delay % 86400) // 3600)
    if delay_hours == '0h' and not delay_days: delay_hours = ''

    delay_minutes = '{}m'.format(((delay % 86400) % 3600) // 60)
    if delay_minutes == '0m' and not delay_hours: delay_minutes = ''

    delay_seconds = '{}s'.format(((delay % 86400) % 3600) % 60)
    if delay_seconds == '0s' and not delay_minutes: delay_seconds = ''

    return '{}{}{}{}'.format(delay_days, delay_hours, delay_minutes, delay_seconds)


def is_disabled_check(check_name):
    wrapper = get_check_wrapper_name(check_name)
    return is_disabled_wrapper(wrapper)


def is_disabled_wrapper(wrapper_name):
    disable_file_path = get_disable_file_path(wrapper_name)
    if os.path.exists(disable_file_path):
        enable_time = get_enable_time(wrapper_name)
        enable_delay = calc_enable_delay(enable_time)
        is_disabled = enable_delay > 0
        return is_disabled
    else:
        return False


def get_disable_file_path(wrapper_name):
    return '{}/{}_alerts_disabled'.format(var_dir, wrapper_name)




### Nagios configuration functions ####################

# Return NRPE configuration, with includes, without comments
# and in the same order than NRPE does (taking account that
# order changes from Deb10)
def get_nrpe_conf():
    return _nrpe_conf_lines


# Private function to recursively get NRPE conf from file
def _get_conf_from_file(file_path):
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        return

    conf_lines = []
    with open(file_path, 'r') as file:
        for line in file:
            line = line.split('#')[0].strip()
            if line:
                if 'include=' in line:
                    conf_file = line.split('=')[1]
                    include = _get_conf_from_file(conf_file)
                    conf_lines.extend(include)
                elif 'include_dir=' in line:
                    conf_dir = line.split('=')[1]
                    include = _get_conf_from_dir(conf_dir)
                    conf_lines.extend(include)
                elif 'check_hda1' in line:
                    continue # Ludo dirty hack to avoid modifying /etc/nrpe/nrpe.cfg
                else:
                    conf_lines.append(line)
    return conf_lines


# Private function to recursively get NRPE conf from directory
def _get_conf_from_dir(dir_path):
    if not os.path.exists(dir_path) or not os.path.isdir(dir_path):
        return

    # Get dir content in the right order (depending on debian_major_version).
    # From Deb10, NRPE uses scandir() with alphasort() function, so we use 'sort' to reproduce it.
    # Before Deb10, NRPE used loaddir(), so we keep 'find' output order because it also uses loaddir().
    command = 'find "{}" -maxdepth 1 -name "*.cfg" 2> /dev/null'.format(dir_path)
    if debian_major_version >= 10:
        command += ' | sort'
    stdout = subprocess.check_output(command, shell=True)
    dir_content = stdout.decode('utf8').split('\n')

    # Process recursively dir_path content
    conf_lines = []
    for path in dir_content:
        if os.path.isfile(path):
            include = _get_conf_from_file(path)
            conf_lines.extend(include)
        elif os.path.isdir(path):
            include = _get_conf_from_dir(path)
            conf_lines.extend(include)
    return conf_lines


# Return the checks that are configured in NRPE
def get_checks_names():
    pattern = re.compile('command\[check_([0-9a-zA-Z_\-]*)\]=')
    check_names = []
    for line in _nrpe_conf_lines:
        match = re.search(pattern, line)
        if match and len(match.groups()) == 1 and match.group(1) not in check_names:
            check_names.append(match.group(1))
    return check_names


# Return all the commands defined for check_name in NRPE configuration
def get_check_commands(check_name):
    pattern = re.compile('command\[check_{}\]=(.*)'.format(check_name))
    commands = []
    for line in _nrpe_conf_lines:
        match = re.search(pattern, line)
        if match and len(match.groups()) == 1:
            commands.append(match.group(1))
    return commands


# Return the checks that have no alerts_wrapper in NRPE configuration
def not_wrapped_checks():
    not_wrapped = []
    for check in get_checks_names():
        if not is_wrapped(check) and check not in not_wrapped:
            not_wrapped.append(check)
    return not_wrapped


# Return True if check is wrapped
def is_wrapped(check_name):
    commands = get_check_commands(check_name)
    if not commands:
        return False
    command = commands[-1]
    return 'alerts_wrapper' in command


# Private function to extract the name of the wrapper from a NRPE config line
def _get_wrapper_name_from_line(line):
    if 'alerts_wrapper' in line:
        words = line.split(' ')
        while '' in words:
            words.remove('')
        for i in range(len(words)):
            if words[i] in ['--name', '-n']:
                return words[i+1]


# Return the names that are defined in the wrappers of the checks
def get_wrappers_names():
    wrapper_names = []
    for line in _nrpe_conf_lines:
        wrapper_name = _get_wrapper_name_from_line(line)
        if wrapper_name:
            wrapper_names.append(wrapper_name)
    return wrapper_names


# Return the wrapper name of the check
def get_check_wrapper_name(check_name):
    commands = get_check_commands(check_name)
    if not commands:
        return
    return _get_wrapper_name_from_line(commands[-1])


def is_check(check_name):
    checks = get_checks_names()
    return check_name in checks


def is_wrapper(wrapper_name):
    wrappers = get_wrappers_names()
    return wrapper_name in wrappers


# Return the checks that have this wrapper name
def get_wrapper_checks(wrapper_name):
    checks = []
    for check in get_checks_names():
        check_wrapper_name = get_check_wrapper_name(check)
        if check_wrapper_name == wrapper_name:
            checks.append(check)
    return checks


# Load NRPE configuration
_nrpe_conf_lines = _get_conf_from_file(nrpe_conf_path)
