#!/usr/bin/env python3
#
# alerts_wrapper wraps an NRPE command and overrides its return code if alert is disabled by monitoringctl.
#
# Source:
#     https://gitea.evolix.org/evolix/ansible-roles/src/branch/stable/nagios-nrpe/
#

lib_dir = '/usr/local/lib/monitoringctl'
prog_version="24.07"

import sys, os
import argparse
import subprocess
from datetime import datetime, timedelta


# Load common lib
if os.path.isdir(lib_dir) and os.path.isfile(lib_dir + '/common.py'):
    sys.path.append(lib_dir)
    import common as lib
else:
    print('ERROR: missing {}/monitoringctl_common module.'.format(lib_dir), file=sys.stderr)
    exit(2)


# Check /var directory
if not os.path.isdir(lib.var_dir):
    lib.error('ERROR: missing ${var_dir} directory.'.format(lib.var_dir))


def show_help():
    help_str = '''
alerts_wrapper wraps an NRPE command and overrides the return code.

Usage: alerts_wrapper --name <WRAPPER_NAME> <CHECK_COMMAND>
Usage: alerts_wrapper <WRAPPER_NAME> <CHECK_COMMAND> (deprecated)

Options
  --name               Wrapper name, it is very recommended to use the check name (like load, disk1…).
                       Special name: 'all' is already hard-coded.
  -h, --help           Print this message and exit.
  -V, --version        Print version and exit.
'''
    print(help_str)


def enable_wrapper(wrapper_name):
    enable_command = '/usr/local/bin/monitoringctl enable {} --message \'Disable time passed.\''.format(wrapper_name)
    if os.getuid() != 0:
        enable_command = 'sudo ' + enable_command
    subprocess.run(enable_command, shell=True)


def main(wrapper_name, check_command):
    disable_file = lib.get_disable_file_path(wrapper_name)
    is_disabled = lib.is_disabled_wrapper(wrapper_name)

    if os.path.exists(disable_file) and not is_disabled:
        enable_wrapper(wrapper_name)

    if is_disabled:
        check_command = 'timeout 8 ' + check_command

    check_rc = 0
    try:
        stdout = subprocess.check_output(check_command, shell=True)
    except subprocess.CalledProcessError as e:
        check_rc = e.returncode
        stdout = e.stdout
    check_stdout = stdout.decode('utf8').strip()  # strip() removes trailing \n

    if is_disabled and check_rc == 124 and not check_stdout:
        check_stdout = 'Check timeout (> 8 sec)'

    if is_disabled:
        # TODO: Pythonize these lib functions
        enable_time = lib.get_enable_time(wrapper_name)
        enable_delay = lib.calc_enable_delay(enable_time)
        delay_str = lib.delay_to_string(enable_delay)

        enable_delay_delta = timedelta(seconds=enable_delay)
        enable_date = datetime.strftime(datetime.now() + enable_delay_delta, '%d %h %Y at %H:%M:%S')

        disable_msg = lib.get_disable_message(wrapper_name)
        if disable_msg:
            disable_msg = '- {} '.format(disable_msg)

        print('ALERT DISABLED until {} ({} left) {}- Check output: {}'.format(enable_date, delay_str, disable_msg, check_stdout))

    else:
        print(check_stdout)

    if is_disabled:
        if check_rc == 0:
            exit(0)  # Nagios OK
        else:
            exit(1)  # Nagios WARNING
    else:
        exit(check_rc)


# Parse arguments

parser = argparse.ArgumentParser(
    prog='alerts_wrapper',
    description='alerts_wrapper wraps an NRPE command and overrides its return code if alert is disabled by monitoringctl.')

parser.add_argument('-V', '--version', action='store_true')
parser.add_argument('-n', '--name', required=True, help='Wrapper name. Using the check name (like "load", "disk1"…) is strongly advised. "all" is a special name already hard-coded.')
parser.add_argument('check_command', help='NRPE check command that will be run by the wrapper.')

# unknown_args is a workaround to get args starting with '--'
args, unknown_args = parser.parse_known_args()

if args.version:
    lib.show_version(prog_version)
    exit(0)

wrapper_name = args.name
for i, arg in enumerate(unknown_args):
    if '"' in arg:
        unknown_args[i] = '\'{}\''.format(arg)
    else:
        unknown_args[i] = '"{}"'.format(arg)
check_command = [args.check_command] + unknown_args
check_command = ' '.join(check_command)


# Run program
main(wrapper_name, check_command)

