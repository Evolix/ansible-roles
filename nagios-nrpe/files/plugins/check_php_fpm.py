#!/usr/bin/python3

"""
check_php_fpm.py is a NRPE check that verifies:

- The status of the PHP-FPM services running on a server.

- The status of the PHP-FPM pools used in an Apache or Nginx vhost:
  - Number of active process relatively to max children (variables warn_children_use_perc and crit_children_use_perc)
  - If max children was recently reached (variable max_children_alert_duration).

Requirements (Debian packages): libfcgi-bin python3-requests

To check manually a pool:
SCRIPT_FILENAME=<STATUS_URI> SCRIPT_NAME=<STATUS_URI> REQUEST_METHOD=GET cgi-fcgi -bind -connect <FPM_SOCKET_PATH>



"""

# Standard library
import os, sys, shutil, subprocess, time, threading, re
from typing import List, Tuple
from datetime import datetime, timedelta
import argparse

# Dependencies
import requests

if not shutil.which('cgi-fcgi'):
    print('Missing binary cgi-fcgi, please install package libfcgi-bin')
    exit(3)

is_lxc = True
if not shutil.which('lxc-ls'):
    is_lxc = False

cmd_list_services = 'systemctl list-units php*-fpm.service --all --plain --no-pager --no-legend'
cmd_list_containers = 'lxc-ls -1 --filter=php'
tpl_lxc_attach = 'lxc-attach -n {container} -- {command}'
tpl_check = 'systemctl is-active {service}'
tpl_status_cgi = 'cgi-fcgi -bind -connect {socket_path}'
cgi_timeout = 7
warn_children_use_perc = 80
crit_children_use_perc = 100
max_children_alert_duration = 10  # in minutes
tpl_service_history_path = '/run/check-php-fpm/{location}/{service}'
tpl_pool_history_path = tpl_service_history_path + '/{pool}'
pool_history_purge_threshold = 200
pool_history_keep_lines = 100

re_php_version = re.compile(r'[0-9]{1,2}(\.[0-9]{1,2})?')
re_active_processes = re.compile(r'^active processes:\s*[0-9]+')
re_max_children_reached = re.compile(r'^max children reached:\s*[0-9]+')



class PoolStatusThread(threading.Thread):
    """ Thread object that get PHP-FMP status with cgi-fcgi and store its output.
    """
    def __init__(self, location: str, service: str, pool: str, socket_path: str, status_uri: str, max_children: int):
        self.location = location
        self.service = service
        self.pool = pool
        self.full_status = None
        self.socket_path = socket_path
        self.status_uri = status_uri
        self.max_children = max_children
        self.active_processes, self.max_children_reached = None, None
        # note: max_active_processes is useless when pm is ondemand because it auto-changes
        self.timestamp = None
        self.is_max_children_reached = False
        self.exception = ''
        self.stderr = ''
        threading.Thread.__init__(self, daemon=True) # needs to be at the end to avoid __hash__() -> AttributeError: 'PoolStatusThread' object has no attribute XX

    def __eq__(self, other):
        """ For comparison. To avoid to have the same PoolStatusThread multiple times in lists.
        """
        if isinstance(other, PoolStatusThread):
            return self.location == other.location and self.service == other.service and self.pool == other.pool
        else:
            return False

    def __hash__(self):
        """ If __eq__() is reimplemented, __hash__() must be too, because it needs to be consistent with __eq__().
        """
        return hash((self.location, self.service, self.pool))

    def __str__(self):
        return 'Pool {}/{}/{} nproc={}/{}, max_reached={}'.format(self.location, self.service, self.pool, self.active_processes, self.max_children, self.max_children_reached)

    def run(self):
        """ Get PHP-FMP status with cgi-fcgi.
        """
        cmd = tpl_status_cgi.format(socket_path=self.socket_path)
        env = { 'SCRIPT_FILENAME': self.status_uri, 'SCRIPT_NAME': self.status_uri, 'REQUEST_METHOD': 'GET' }
        try:
            stdout, stderr, rc = execute(cmd, timeout=cgi_timeout, extra_env_vars=env)
            self.full_status = stdout
            self.timestamp = round(datetime.now().timestamp())
            for line in stdout:
                if re_active_processes.fullmatch(line):
                    self.active_processes = int(line.split(':')[1].strip())
                if re_max_children_reached.fullmatch(line):
                    self.max_children_reached = int(line.split(':')[1].strip())
            self.stderr = '\n'.join(stderr)
        except Exception as e:
            self.exception = e

    def get_history_path(self):
        return tpl_pool_history_path.format(location=self.location, service=self.service, pool=self.pool)

    def load_history(self):
        """ Return a list of tuples (datetime, active_processes, max_children_reached, max_children)
        """
        path = self.get_history_path()
        history = []
        if not os.path.exists(path):
            return []
        with open(path, encoding='utf-8') as f:
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                if not line or line == '':
                    continue
                words = line.split()
                if words and len(words) != 4: # corrupted line
                    print('warning: removing pool history {} beause corrupted'.format(path))
                    os.remove(path)
                    break
                try:
                    words = [ int(w) for w in words if w ]
                    words[0] = datetime.fromtimestamp(words[0])
                    if datetime.now() - words[0] > timedelta(minutes = max_children_alert_duration):
                        continue
                    history.append(words)
                except Exception as e: # corrupted line
                    #print(e)
                    print('warning: removing pool history {} beause corrupted'.format(path))
                    os.remove(path)
                    break
        if len(lines) > pool_history_purge_threshold:
            self.autoclean_history()
        return history

    def autoclean_history(self):
        path = self.get_history_path()
        with open(path, 'r+', encoding='utf-8') as f:
            lines = f.readlines()
            f.seek(0)
            f.writelines(lines[-pool_history_keep_lines:])
            f.truncate()

    def save(self):
        """ Append to history file a list of tuples (datetime, active_processes, max_children_reached, max_children)
        """
        path = self.get_history_path()
        with open(path, 'a', encoding='utf-8') as f:
            f.write('{} {} {} {}\n'.format(self.timestamp, self.active_processes, self.max_children_reached, self.max_children))



def main():
    """ List PHP-FPM services on host and in LXC, then check if they are active.
    """
    global warn_children_use_perc, crit_children_use_perc, max_children_alert_duration

    parser = argparse.ArgumentParser(prog='check_php_fpm.py')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print also OK pools.')
    parser.add_argument('--php-version', help='Limit search to PHP version (7, 7.4, 8.2…).')
    parser.add_argument('--pool', help='Limit search to this pool and the FPM service running it.')
    parser.add_argument('--children-warn', default=warn_children_use_perc, help='WARNING if number of children exceeds this percentage (0-100, default {})'.format(warn_children_use_perc))
    parser.add_argument('--children-crit', default=crit_children_use_perc, help='CRITICAL if number of children exceeds this percentage (0-100, default {})'.format(crit_children_use_perc))
    parser.add_argument('--max-children-time', default=10, help='WARNING when max children has been reached in N previous minutes (default 10)')

    args = parser.parse_args()
    is_verbose = args.verbose
    target_pool = args.pool
    php_version = args.php_version

    if target_pool and php_version:
        print('Error: please do not use option --php-version with --pool.', file=sys.stderr)
        exit(1)
    if php_version and not re.fullmatch(re_php_version, php_version):
        print('Error: incorrect --php-version.', file=sys.stderr)
        exit(1)
    try:
        warn_children_use_perc = int(args.children_warn)
    except:
        print('Error: --children-warn option must be an integer.', file=sys.stderr)
        exit(1)
    try:
        crit_children_use_perc = int(args.children_crit)
    except:
        print('Error: --children-crit option must be an integer.', file=sys.stderr)
        exit(1)
    try:
        max_children_alert_duration = int(args.max_children_time)
    except:
        print('Error: --max-children-time option must be an integer.', file=sys.stderr)
        exit(1)
    if not (0 <= warn_children_use_perc <= 100 or 0 <= crit_children_use_perc <= 100):
        print('Error: --children-warn and --children-crit options must be between 0 and 100.', file=sys.stderr)
        exit(1)
    if not (warn_children_use_perc <= crit_children_use_perc):
        print('Error: --children-warn must be inferior to --children-crit.', file=sys.stderr)
        exit(1)
    if max_children_alert_duration < 0:
        print('Error: --max-children-time must be a positive integer.', file=sys.stderr)
        exit(1)

    services = list_all_php_fpm_services(php_version)

    pools = get_pools(services, target_pool)
    if target_pool:
        services = [ pools[0][0:2] ]

    critical, warning = False, False

    actives, inactives = [], []
    for (location, service) in services:
        service_history_path = tpl_service_history_path.format(location=location, service=service)
        if not os.path.exists(service_history_path):
            os.makedirs(service_history_path)

        return_code = check_service(service, location)
        service = service
        if return_code == 0:
            actives.append((location, service))
        else:
            inactives.append((location, service))
            critical = True

    jobs = []
    for pool in pools:
        is_in_inactive = False
        # Do not check pools of inactive services
        for service, _ in inactives:
            if pool[1] == service:
                is_in_inactive = True
                break
        if is_in_inactive: continue

        #print("Check", pool)
        t = PoolStatusThread(*pool)
        t.start()
        jobs.append(t)

    for job in jobs:
        job.join()

    crit_pools, warn_pools = [], []
    for pool_status in jobs:
        #print(pool_status)

        pool_history = pool_status.load_history()
        #print(pool_history)

        if pool_status.exception or pool_status.stderr:
            critical = True
            crit_pools.append(pool_status)
        else:
            pool_status.save()

        # Check if counter of max children reached has increased
        if pool_history:
            if pool_status.max_children_reached:
                last_max_children_reached = pool_status.max_children_reached
            else:
                last_max_children_reached = max([ history[2] for history in pool_history ])
            min_max_children_reached = min([ history[2] for history in pool_history ])
            if last_max_children_reached > min_max_children_reached:
                # Max children was reached
                pool_status.is_max_children_reached = True
                warning = True
                if pool_status not in crit_pools:
                    warn_pools.append(pool_status)

        # Check actives process number
        if pool_status.active_processes and pool_status.max_children:
            children_use_perc = round(100 * pool_status.active_processes / pool_status.max_children)
            if children_use_perc >= crit_children_use_perc:
                critical = True
                if pool_status not in crit_pools:
                    crit_pools.append(pool_status)
            elif children_use_perc >= warn_children_use_perc:
                warning = True
                warn_pools.append(pool_status)

    # Print results

    status = 'OK'
    rc = 0
    if critical:
        status = 'CRITICAL'
        rc = 2
    elif warning:
        status = 'WARNING'
        rc = 1

    print('{} - {} CRIT / {} WARN / {} OK\n'.format(status, len(inactives) + len(crit_pools), len(warn_pools), len(actives)))

    for (location, service) in inactives:
        location_str = '' if location == 'host' else ' in container {}'.format(location)
        print('CRITICAL - service {} is inactive or failed{}!'.format(service, location_str))

    for pool in crit_pools:
        location_str = ' on host' if location == 'host' else ' in container {}'.format(pool.location)
        if pool.exception:
            if type(pool.exception) is subprocess.TimeoutExpired:
                print('CRITICAL - timeout of pool {}/{}{} (spawning many children, or max children reached?)'.format(pool.service, pool.pool, location_str))
        else:
            print('CRITICAL - pool {}/{}{}, {} children (max {})'.format(pool.service, pool.pool, location_str, pool.active_processes, pool.max_children))
        if is_verbose and target_pool and pool.full_status:
            print()
            print('\n'.join(pool.full_status))

    for pool in warn_pools:
        if pool in crit_pools:
            continue
        location_str = ' on host' if location == 'host' else ' in container {}'.format(pool.location)
        if pool.is_max_children_reached:
            print('WARNING - pool {}/{}{}, max children reached < {} min, currently {} children (max {})'.format(pool.service, pool.pool, location_str, max_children_alert_duration, pool.active_processes, pool.max_children))
        else:
            print('WARNING - pool {}/{}{}, {} children (max {})'.format(pool.service, pool.pool, location_str, pool.active_processes, pool.max_children))
        if is_verbose and target_pool and pool.full_status:
                print()
                print('\n'.join(pool.full_status))

    # Print OK services, but not OK pools (would be to long)
    for (location, service) in actives:
        location_str = ' on host' if location == 'host' else ' in container {}'.format(location)
        print('OK - service {}{}'.format(service, location_str))

    # Print OK pools
    if is_verbose:
        for pool in jobs:
            if pool in crit_pools or pool in warn_pools: continue
            print('OK - pool {}/{} in {}, {} children (max {})'.format(pool.service, pool.pool, pool.location, pool.active_processes, pool.max_children))
            if target_pool and pool.full_status:
                print()
                print('\n'.join(pool.full_status))

    # Print performance data
    print('| ', end='')
    for pool in jobs:
        warn_thres = round(pool.max_children * warn_children_use_perc / 100)
        crit_thres = round(pool.max_children * crit_children_use_perc / 100)
        # format: label=value;warn;crit;min;max
        print('{}/{}/{}={};{};{};0;{};'.format(pool.location, pool.service, pool.pool, pool.active_processes, warn_thres, crit_thres, pool.max_children), end='| ')

    sys.exit(rc)


def list_containers():
    """ List LXC containers which contain 'php' in their name.
    """
    containers = []
    if is_lxc:
        containers, _, _ = execute(cmd_list_containers)
    return containers

def list_all_php_fpm_services(version: str = None):
    """ Return all PHP-FPM services (host and containers) in a tuple.
    version: limit search to this version. Examble : '7.4', '8.2'…
    Return format: ('host'|container_name, service_name).
    """
    services = []
    locations = list_containers() + ['host']
    version_found = False
    for location in locations:
        cmd = cmd_list_services if location == 'host' else tpl_lxc_attach.format(container=location, command=cmd_list_services)
        stdout_lines, _, _ = execute(cmd)
        for line in stdout_lines:
            service = line.split()[0].rstrip('.service')
            if version:
                if version in service:
                    services.append((location, service))
                    version_found = True
            else:
                services.append((location, service))
    if version and not version_found:
        print('Error: PHP version {} not found.'.format(version), file=sys.stderr)
        exit(1)
    return services

def check_service(service: str, location: str = 'host'):
    """ Check PHP-FPM service.
    service: service name. Example: php7.3-fpm.service.
    location: (optional) 'host' or  LXC container name.
    """
    location_str = '' if location == 'host' else ' in container {}'.format(location)

    cmd_check = tpl_check.format(service=service)
    cmd = cmd_check if location == 'host' else tpl_lxc_attach.format(container=location, command=cmd_check)
    lines_stdout, _, rc = execute(cmd)
    return rc

def get_pools(services: Tuple[str, str], target_pool: str = None):
    """ Return a list of tuple (service, location, socket_path, status_uri, max_children)
    representing the pools.
    target_pool: limit search to this pool.
    """
    pools = []
    target_pool_found = False
    for (location, service) in services:
        pool_path = get_pool_directory_path(service, location)
        for filename in os.listdir(pool_path):
            if filename == 'www.conf': continue
            basename, extension = os.path.splitext(filename)
            if target_pool:
                if basename != target_pool:
                    continue
                else:
                    target_pool_found = True
            if extension != '.conf': continue
            socket_path, status_uri, max_children = None, None, None
            conf_path = pool_path + '/' + filename
            with open(conf_path, encoding='utf-8') as file:
                for line in file:
                    line = line.split('=')
                    if line[0].strip() == 'listen':
                        socket_path = line[1].strip()
                    if line[0].strip() == 'pm.status_path':
                        status_uri = line[1].strip()
                    if line[0].strip() == 'pm.max_children':
                        max_children = int(line[1].strip())
            if not socket_path or not status_uri or not max_children:
                continue

            # Check if pool is used in Apache
            pool_used = False
            vhost_path = '/etc/apache2/sites-enabled/{}'.format(filename)
            if os.path.exists(vhost_path):
                with open(vhost_path, encoding='utf-8') as f:
                    for line in f:
                        if 'SetHandler' in line and socket_path in line:
                            pool_used = True
                            break
            # Check if pool is used in Nginx
            vhost_path = '/etc/nginx/sites-enabled/{}'.format(filename)
            if os.path.exists(vhost_path):
                with open(vhost_path, encoding='utf-8') as f:
                    for line in f:
                        words = line.strip().strip(';').split()
                        if 'fastcgi_pass' in words or 'server' in words:
                            if 'unix:{}'.format(socket_path) in words:
                                pool_used = True
                                break

            if pool_used:
                pools.append((location, service, basename, socket_path, status_uri, max_children))

    if target_pool and not target_pool_found:
        print('Error: Pool {} not found, or missing expected directives (listen, pm.status_path and pm.max_children).'.format(target_pool), file=sys.stderr)
        exit(1)
    return pools

def get_pool_directory_path(service: str, location: str = 'host'):
    """ Return the standard path of the pool directory of this PHP-FMP service.
    php_service: PHP-FPM service name
    location: (optional) 'host' or container name.
    """
    version = service.lstrip('php').rstrip('-fpm')
    version_array = list(map(int, version.split('.')))
    path = '/etc/php/{}/fpm/pool.d'.format(version)
    if not os.path.exists(path) and version_array[0] <= 5:
        path = '/etc/php{}/fpm/pool.d'.format(version_array[0])
    if location != 'host':
        path = '/var/lib/lxc/{}/rootfs'.format(location) + path
    return path

def execute(cmd: str, timeout: int = None, shell: bool = False, extra_env_vars: List[str] = []):
    """Execute shell command.
    - cmd: the command to execute
    - timeout: in seconds
    - shell: if True, pass directly the command to shell (useful for pipes).
        Before using shell=True, consider this security warning:
          https://docs.python.org/3/library/subprocess.html#security-considerations
    Return stdout and stderr as arrays of UTF-8 strings, and the return code.
    """
    if not shell:
        cmd = cmd.split()

    env = os.environ.copy()
    env.update(extra_env_vars)

    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=shell, env=env)
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as e:
        proc.kill()
        raise e
    except Exception as e:
        print('Failed to execute command: {}'.format(' '.join(cmd)))
        exit(3) # UNKNOWN

    stdout_lines = stdout.decode('utf-8').splitlines()
    stderr_lines = stderr.decode('utf-8').splitlines()

    return stdout_lines, stderr_lines, proc.returncode


## Entry point
if __name__ == '__main__':
    main()
