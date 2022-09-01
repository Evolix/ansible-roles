#!/usr/bin/python3
# 
# Vérifie si les domaines listés dans les configurations de Apache,
# Nginx et Haproxy pointent bien sur le serveur.
# 
# Développé par Will
# 

list_domains_path = '/usr/local/sbin/list_domains.py'
excludes_path = '/etc/nagios/domains_exclude.list'
includes_path = '/etc/nagios/domains_include.list'

import os
import sys
import re
import subprocess
import threading
import time
import argparse

#import importlib.machinery
#list_domains = importlib.machinery.SourceFileLoader('list_domains.py', list_domains_path).load_module()


def execute(cmd):
    """Execute Bash command cmd.
    Return stdout and stderr as arrays of UTF-8 strings."""

    proc = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()

    stdout_lines = stdout.decode('utf-8').splitlines()
    stderr_lines = stderr.decode('utf-8').splitlines()

    return stdout_lines, stderr_lines


def get_my_ips():
    """Return localhost IPs."""
    stdout, stderr = execute('hostname -I')
    if not stdout:
        return []
    return stdout[0].strip().split()


def dig(domain):
    """Return dig +short result on domain as a list."""
    stdout, stderr = execute('dig +short {}'.format(domain))
    return stdout

def list_apache_domains():
    """Return a dict containing :
    - key: Apache domain (from command "apache2ctl -D DUMP_VHOSTS").
    - value: a list of strings "apache:<VHOST_PATH>:<LINE_IN_BLOCK>"
    """
    domains = {}

    try:
        stdout, stderr = execute("apache2ctl -D DUMP_VHOSTS")
    except:
        # Apache is not on the server
        return domains

    vhost_infos = ""
    for line in stdout:
        dom = ""
        words = line.strip().split()

        if "namevhost" in line and len(words) >= 5:
            # line format: port <PORT> namevhost <DOMAIN> (<VHOST_PATH>:<LINE_IN_BLOCK>)
            dom = words[3]
            vhost_infos = "apache:" + words[4].strip('()')

        elif "alias" in line and len(words) >= 2:
            # line format: alias <DOMAIN>
            dom = words[1]  # vhost_infos defined in previous lines

        if dom:
            if dom not in domains:
                domains[dom] = []
            if vhost_infos not in domains[dom]:
                domains[dom].append(vhost_infos)

    return domains


class ResolutionThread(threading.Thread):
    
    def __init__(self, domain):
        threading.Thread.__init__(self, daemon=True)
        self.domain = domain
        self.ips = []

    def run(self):
        """Resolve domain with dig."""
        try:
            dig_results = dig(self.domain)
            
            if not dig_results:
                return

            for line in dig_results:
                match = re.search('^([0-9abcdef\.:]+)$', line)
                if match:
                    ip = match.group(1)
                    if ip not in self.ips:
                        self.ips.append(ip)

        except Exception as e:
            #print(e)
            return


def run_check_domains(domains):
    """Check resolution of domains (list)."""

    excludes = ['_']
    timeout = 5

    my_ips = get_my_ips()

    domains_noexcludes = [dom for dom in domains if dom not in excludes]

    jobs = []
    for dom in domains_noexcludes:
        #print(d)
        t = ResolutionThread(dom)
        t.start()
        jobs.append(t)
    
    # Let <timeout> secs to DNS servers to answer in jobs threads
    time.sleep(timeout)

    timeout_domains = []
    none_domains = []
    outside_ips = {}
    ok_domains = []

    for j in jobs:
        if j.is_alive():
            timeout_domains.append(j.domain)
            continue

        if not j.ips:
            none_domains.append(j.domain)
            continue
        
        is_outside = False
        for ip in j.ips:
            if ip not in my_ips:
                is_outside = True
                break
        if is_outside:
            outside_ips[j.domain] = j.ips
        else:
            ok_domains.append(j.domain)

    return timeout_domains, none_domains, outside_ips, ok_domains
   

def output_check_mode(timeout_domains, none_domains, outside_ips, ok_domains):
    """Output result for check mode.
    For now, consider everyting as warnings to avoid too much alerts.
    """
    
    n_ok = len(ok_domains)
    n_warnings = len(timeout_domains) + len(none_domains) + len(outside_ips)

    msg = 'WARNING' if n_warnings else 'OK'

    print('{} - 0 UNK / 0 CRIT / {} WARN / {} OK \n'.format(msg, n_warnings, n_ok))
    
    if timeout_domains or none_domains or outside_ips:
        for d in timeout_domains:
            print('WARNING - timeout resolving {}'.format(d))
        for d in none_domains:
            print('WARNING - no resolution for {}'.format(d))
        for d in outside_ips:
            print('WARNING - {} pointing elsewhere ({})'.format(d, ' '.join(outside_ips[d])))
    
    sys.exit(1) if n_warnings else sys.exit(0)


def output_friendly_mode(doms, timeout_domains, none_domains, outside_ips):
    if timeout_domains or none_domains or outside_ips:
        if timeout_domains: print('\nTimeouts:')
        for d in timeout_domains:
            print('\t{} {}'.format(d, ' '.join(doms[d])))
        if none_domains: print('\nNo resolution:')
        for d in none_domains:
            print('\t{} {}'.format(d, ' '.join(doms[d])))
        if outside_ips: print('\nPointing elsewhere:')
        for d in outside_ips:
            print('\t{} {} -> [{}]'.format(d, ' '.join(doms[d]), ' '.join(outside_ips[d])))

        sys.exit(1)

    print('Domains resolve to right IPs !')


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('action', metavar='ACTION', help='Values: check-dns, list')
    parser.add_argument('-o', '--output-style', help='Values: stdout (default), nrpe')
    parser.add_argument('-a', '--all-domains', action='store_true', help='Include all domains (default).')
    parser.add_argument('-ap', '--apache-domains', action='store_true', help='Include Apache domains.')
    parser.add_argument('-ng', '--nginx-domains', action='store_true', help='Include Nginx domains.')
    parser.add_argument('-ha', '--haproxy-domains', action='store_true', help='Include HaProxy domains.')
    args = parser.parse_args()
    
    if args.action not in ['check-dns', 'list']:
        if args.output_style == 'nrpe':
            print('UNKNOWN - unkown {} action, use -h option for help.'.format(args.action))
            sys.exit(3)
        else:
            print('Unkown {} action, use -h option for help.'.format(args.action))
            sys.exit(1)
   
    if not (args.all_domains or args.apache_domains or args.nginx_domains or args.haproxy_domains):
        print('Domains not specified, looking for all domains (default).')
        args.all_domains = True

    doms = []
   
    if args.all_domains:
        doms.extend(list_apache_domains())
    
    else:
        if args.apache_domains:
            doms.extend(list_apache_domains())
        if args.nginx_domains:
            print("Option --nginx-domains not supported yet.")
        if args.haproxy_domains:
            print("Option --haproxy-domains not supported yet.")
    
    if not doms:
        if args.output_style == 'nrpe':
            print('UNKNOWN - No domain found on this server.')
            sys.exit(3)
        else:
            print('No domain found on this server.')
            sys.exit(1)
    
    timeout_domains, none_domains, outside_ips, ok_domains = run_check_domains(doms.keys())
    
    if args.check:
        output_check_mode(timeout_domains, none_domains, outside_ips, ok_domains)
    
    else:
        output_friendly_mode(doms, timeout_domains, none_domains, outside_ips)


if __name__ == '__main__':
    main(sys.argv[1:])
