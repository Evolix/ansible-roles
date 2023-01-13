#!/usr/bin/python3
#
# Execute 'evodomains --help' for usage.
#
# Evodomains is a Python script to facilitate the management
# of a server's domains.
# It's scope is Apache, Nginx, HaProxy and SSL certificates domains.
# It can list domains, check domains records, and will permit (in the future)
# to remove domains from vhosts configuration and remove certificate files.
#
# Developped by Will
#

ignored_domains_path = '/etc/evolinux/domains/ignored_domains.list'
included_domains_path = '/etc/evolinux/domains/included_domains.list'
allowed_ips_path = '/etc/evolinux/domains/allowed_ips.list'
haproxy_conf_path = '/etc/haproxy/haproxy.cfg'

import os
import sys
import re
import subprocess
import threading
import time
import argparse
import json
try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.backends import default_backend
    from cryptography.x509.oid import NameOID, ExtensionOID
except:
    pass

#TODO: improve data structure, example:
""" "*.cybercartes.com": [
    {
        origin: haproxy,
        type: certificate,
        path: /etc/haproxy/ssl/cybercartes-www_wildcard.cybercartes.com.pem,
        attribute: CN
        ssl_enabled: True
    },
    {
        origin: apache,
        type: config,
        path: /etc/apache/sites-enabled/default.conf,
        line: 42
        ssl_enabled: False
    }
]"""
#TODO: fix line numbers (apache, nginx), line of virtual host block

def print_verbose(s):
    if do_verbose_print:
        print('Warning: '.format(s))


def execute(cmd, shell=False):
    """Execute Bash command.
    - cmd: the command to execute
    - shell: if True, pass directly the command to shell (useful for pipes).
    Before use shell=True, consider security warning:
      https://docs.python.org/3/library/subprocess.html#security-considerations

    Return stdout and stderr as arrays of UTF-8 strings, and the return code."""

    if not shell:
        cmd = cmd.split()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=shell)
    stdout, stderr = proc.communicate()

    stdout_lines = stdout.decode('utf-8').splitlines()
    stderr_lines = stderr.decode('utf-8').splitlines()

    return stdout_lines, stderr_lines, proc.returncode


def get_allowed_ips():
    """Return the list of IPs the domains are allowed to point to."""

    # Server IPs
    stdout, stderr, rc = execute('hostname -I')
    if not stdout:
        return []
    ips = stdout[0].strip().split()

    # Custom allowed IPs from config file
    with open(allowed_ips_path, encoding='utf-8') as f:
        for line in f:
            ip = strip_comments(line).strip(' \t;')
            ips.append(ip)

    return ips


def dig(domain):
    """Return "dig +short $domain", as a list of lines."""
    stdout, stderr, rc = execute('dig +short {}'.format(domain))
    return stdout


def strip_comments(string):
    """Return string with any # comment removed.""" 
    return string.split('#')[0]


def list_apache_domains():
    """Parse Apache dynamic config in search of domains.
    Return a dict containing:
    - key: Apache domain (from command "apache2ctl -D DUMP_VHOSTS").
    - value: a list of strings "apache:<VHOST_PATH>:<LINE_IN_BLOCK>"
    """
    domains = {}

    try:
        stdout, stderr, rc = execute('apache2ctl -D DUMP_VHOSTS')
    except:
        # Apache is not present on the server
        return domains

    vhost_infos = ''
    for line in stdout:
        dom = ''
        words = line.strip().split()

        if 'namevhost' in line and len(words) >= 5:
            # line format: port <PORT> namevhost <DOMAIN> (<VHOST_PATH>:<LINE_IN_BLOCK>)
            dom = words[3].strip()
            vhost_infos = 'apache:' + words[4].strip('()')

        elif 'alias' in line and len(words) >= 2:
            # line format: alias <DOMAIN>
            dom = words[1].strip()  # vhost_infos defined in previous lines

        if dom:
            if dom not in domains:
                domains[dom] = []
            if vhost_infos not in domains[dom]:
                domains[dom].append(vhost_infos)

    return domains


def list_nginx_domains():
    """Parse Nginx dynamic config in search of domains.
    Return a dict containing :
    - key: Nginx domain (from command "nginx -T").
    - value: a list of strings "nginx:<VHOST_PATH>:<LINE_IN_BLOCK>"
    """
    domains = {}

    try:
        stdout, stderr, rc = execute('nginx -T')
    except:
        # Nginx is not present on the server
        return domains

    line_number = 1
    config_file_path = ''

    for line in stdout:
        if '# configuration file' in line:
            # line format : # configuration file <PATH>:
            words = line.strip(' \t;').split()
            config_file_path = words[3].strip(' :')
            continue

        if 'server_name ' in line:
            # TODO: améliorer le if (cas tabulation)
            # line format : server_name <DOMAIN1> [<DOMAINS2 ...];
            line = strip_comments(line)
            words = line.strip(' \t;').split()

            for d in words[1:]:
                dom = d.strip()
                vhost_infos = 'nginx:{}:{}'.format(config_file_path, line_number)
                if dom not in domains:
                    domains[dom] = []
                if vhost_infos not in domains[dom]:
                    domains[dom].append(vhost_infos)

        line_number += 1  # increment line number for next round

        if 'server {' in line:
            # TODO: améliorer le if (cas plusieurs espaces)
            # line format : server {
            line_number = 0

    return domains


def list_haproxy_acl_domains():
    """Parse HaProxy config file in search of domain ACLs or files containing list of domains.
    Return a dict containing :
    - key: HaProxy domains (from ACLs in /etc/haproxy/haproxy.cgf).
    - value: a list of strings "haproxy:/etc/haproxy/haproxy.cfg:<LINE_IN_CONF>"
    """
    domains = {}

    if not os.path.isfile(haproxy_conf_path):
        # HaProxy is not installed
        print_verbose('{} not found'.format(haproxy_conf_path))
        return domains

    # Domains from ACLs
    with open(haproxy_conf_path, encoding='utf-8') as f:
        line_number = 0
        files = []
        for line in f.readlines():
            line_number += 1

            # Handled line format:
            #    acl <ACL_NAME> [hdr|hdr_reg|hdr_end](host) [-i] <STRING> [<STRING> [...]]
            #    acl <ACL_NAME> [hdr|hdr_reg](host) [-i] -f <FILE>

            line = strip_comments(line).strip()

            if (not line) or (not line.startswith('acl')):
                continue
            if 'hdr(host)' not in line and 'hdr_reg(host)' not in line and 'hdr_end(host)' not in line:
                continue

            # Remove 'acl <ACL_NAME>' from line
            line = ' '.join(line.split()[2:])

            is_file = False
            if ' -f ' in line:
                is_file = True

            # Limit: does not handle regex

            words = line.split()
            for word in line.split():
                if word in ['hdr(host)', 'hdr_reg(host)', 'hdr_end(host)', '-f', '-i']:
                    continue

                if is_file:
                    if word not in files:
                        print('Found HaProxy domains file {}'.format(word))
                        files.append(word)
                else:
                    dom_infos = 'haproxy:{}:{}'.format(haproxy_conf_path, line_number)
                    if word not in domains:
                        domains[word] = []
                    if dom_infos not in domains[word]:
                        domains[word].append(dom_infos)

        for f in files:
            domains_to_add = read_haproxy_domains_file(f, 'haproxy')
            domains.update(domains_to_add)

#TODO remove (call elsewhere)
    # Domains from HaProxy certificates
#    domains_to_add = list_haproxy_certs_domains()
#    domains.update(domains_to_add)

    return domains


def read_haproxy_domains_file(domains_file_path, origin):
    """Process a file containing a list of domains :
    - domains_file_path: path of the file to parse
    - origin: string keyword to prepend to the domains infos. Exemple: 'haproxy'
    Return a dict containing :
    - key: domain (from domains_file_path)
    - value: a list of strings "origin:domains_file_path:<LINE_IN_BLOCK>"
    """
    domains = {}

    try:
        with open(domains_file_path, encoding='utf-8') as f:
            line_number = 0
            for line in f.readlines():
                line_number += 1

                dom = strip_comments(line).strip()
                if not dom:
                    continue

                dom_infos = '{}:{}:{}'.format(origin, domains_file_path, line_number)
                if dom not in domains:
                    domains[dom] = []
                if dom_infos not in domains[dom]:
                    domains[dom].append(dom_infos)

    except FileNotFoundError as e:
        print('Error: FileNotFound', domains_file_path)
        print(e)

    return domains


def list_haproxy_certs_domains():
    """Return the domains present in HaProxy SSL certificates.
    Return a dict containing:
    - key: domain (from domains_file_path)
    - value: a list of strings "haproxy_certs:cert_path:CN|SAN"
    """
    domains = {}

    # Check if HaProxy version supports "show ssl cert" command
    supports_show_ssl_cert = does_haproxy_support_show_ssl_cert()

    if supports_show_ssl_cert:
        socket = get_haproxy_stats_socket()
        # Ajoute l'IP locale dans le cas d'un port TCP (au lieu d'un socket Unix)
        if socket.startswith(':'):
            socket = 'tcp:127.0.0.1{}'.format(socket)

        print('echo "show ssl cert" | socat stdio {}'.format(socket))
        stdout, stderr, rc = execute('echo "show ssl cert" | socat stdio {}'.format(socket), shell=True)

        for cert_path in stdout:
            if cert_path.strip().startswith('#'):
                continue
            if os.path.isfile(cert_path):
                domains_to_add = list_cert_domains(cert_path, 'haproxy_certs')
                domains.update(domains_to_add)

    else:
        if not os.path.isfile(haproxy_conf_path):
            # HaProxy is not installed
            print_verbose('{} not found'.format(haproxy_conf_path))
            return domains

        # Get HaProxy certificates paths (can be directory or file)
        # Line format : bind *:<PORT> ssl crt <CERT_PATH>
        cert_paths = []
        with open(haproxy_conf_path, encoding='utf-8') as f:
            for line in f.readlines():
                line = strip_comments(line).strip()
                if not line: continue
                if ' crt ' in line:
                    crt_index = line.find(' crt ')
                    subs = line[crt_index+5:]
                    cert_path = subs.split(' ')[0]  # in case other options are after cert path
                    cert_paths.append(cert_path)
            print("hap certs", cert_paths)

        for cert_path in cert_paths:
            if os.path.isfile(cert_path):
                print(cert_path)
                domains_to_add = list_cert_domains(cert_path, 'haproxy_certs')
                domains.update(domains_to_add)
            elif os.path.isdir(cert_path):
                for f in os.listdir(cert_path):
                    p = cert_path + f
                    if os.path.isfile(p):
                        domains_to_add = list_cert_domains(p, 'haproxy_certs')
                        domains.update(domains_to_add)

    return domains


def does_haproxy_support_show_ssl_cert():
    """Return True if HaProxy version supports 'show ssl cert' command (version >= 2.2)."""

    stdout, stderr, rc = execute('dpkg -l haproxy | grep ii', shell=True)

    supports_show_ssl_cert = False

    if rc == 0:
        for line in stdout:
            words = line.strip().split()
            if len(words) >= 3 and words[1] == 'haproxy':
                version = words[2]
                [major, minor] = version.split('.')[:2]
                if int(major) >= 2 and int(minor) >= 2:
                    supports_show_ssl_cert = True

    return supports_show_ssl_cert


def get_haproxy_stats_socket():
    """Return HaProxy stats socket."""

    with open(haproxy_conf_path, encoding='utf-8') as f:
        line_number = 0
        for line in f.readlines():
            words = line.strip().split()
            if len(words) >= 3 and words[0] == 'stats' and words[1] == 'socket':
                i
                return words[2]

    return None


def list_cert_domains(cert_path, origin):
    """Return the domains present in a X.509 PEM certificate.
    - cert_path: path of the certificate
    - origin: string keyword to prepend to the domains infos. Exemple: 'haproxy_certs'
    Return a dict containing :
    - key: domain (from the certificate)
    - value: a list of strings "origin:cert_path:CN|SAN"
    """
    domains = {}

    with open(cert_path, 'rb') as f:
        try:
            cert = x509.load_pem_x509_certificate(f.read(), default_backend())
        except ValueError:
            print_verbose('Could not load certificate file {}.'.format(cert_path))
            return domains

        # Common name
        cn_list = cert.subject.get_attributes_for_oid(NameOID.COMMON_NAME)
        if cn_list and len(cn_list) > 0:
           dom = cn_list[0].value
           dom_infos = '{}:{}:CN'.format(origin, cert_path)
           if dom not in domains:
               domains[dom] = []
           if dom_infos not in domains[dom]:
               domains[dom].append(dom_infos)

        # Subject Alernative Name
        try:
            san_ext = cert.extensions.get_extension_for_oid(ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
            for dom in san_ext.value.get_values_for_type(x509.DNSName):
                dom_infos = '{}:{}:SAN'.format(origin, cert_path)
                if dom not in domains:
                    domains[dom] = []
                if dom_infos not in domains[dom]:
                    domains[dom].append(dom_infos)
        except x509.ExtensionNotFound:
            pass

    return domains


class DNSResolutionThread(threading.Thread):
    """Thread that executes a dig."""

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

    allowed_ips = get_allowed_ips()

    with open(ignored_domains_path, encoding='utf-8') as f:
        for line in f:
            domain = strip_comments(line).strip()
            if not domain: continue
            excludes.append(domain)

    jobs = []
    timeout_domains = []
    none_domains = []
    outside_ips = {}
    ok_domains = []

    for d in domains:
        if d in excludes:
            ok_domains.append(d)
            continue

        #TODO: handle partially wilcards: check root domain example.com for *.example.com

        t = DNSResolutionThread(d)
        t.start()
        jobs.append(t)

    # Let <timeout> secs to DNS servers to reply to jobs threads queries
    time.sleep(timeout)

    for j in jobs:
        if j.is_alive():
            timeout_domains.append(j.domain)
            continue

        if not j.ips:
            none_domains.append(j.domain)
            continue

        is_outside = False
        for ip in j.ips:
            if ip not in allowed_ips:
                is_outside = True
                break
        if is_outside:
            outside_ips[j.domain] = j.ips
        else:
            ok_domains.append(j.domain)

    return timeout_domains, none_domains, outside_ips, ok_domains


def output_nrpe_mode(timeout_domains, none_domains, outside_ips, ok_domains):
    """Output result for check mode.
    For now, never output critical alerts.
    """

    n_ok = len(ok_domains)
    n_warnings = len(timeout_domains) + len(none_domains) + len(outside_ips)

    msg = 'WARNING' if n_warnings else 'OK'

    print('{} - 0 UNK / 0 CRIT / {} WARN / {} OK \n'.format(msg, n_warnings, n_ok))

    if timeout_domains or none_domains or outside_ips:
        for d in timeout_domains:
            print('WARNING - timeout resolving {}'.format(d))
        for d in none_domains:
            print('WARNING - no resolution for {}'.format(d))
        for d in outside_ips:
            print('WARNING - {} pointing elsewhere ({})'.format(d, ' '.join(outside_ips[d])))

    sys.exit(1) if n_warnings else sys.exit(0)


def output_human_mode(doms, timeout_domains, none_domains, outside_ips):
    if timeout_domains or none_domains or outside_ips:
        if timeout_domains: print('\nTimeouts:')
        for d in timeout_domains:
            print('\t{} {}'.format(d, ' '.join(doms[d])))
        if none_domains: print('\nNo resolution:')
        for d in none_domains:
            print('\t{} {}'.format(d, ' '.join(doms[d])))
        if outside_ips: print('\nPointing elsewhere:')
        for d in outside_ips:
            print('\t{} {} -> [{}]'.format(d, ' '.join(doms[d]), ' '.join(outside_ips[d])))

        sys.exit(1)

    print('Domains resolve to right IPs !')


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('action', metavar='ACTION', help='Values: check-dns, list')
    parser.add_argument('-o', '--output-style', help='Values: json, human (default), nrpe')
    parser.add_argument('-a', '--all-domains', action='store_true', help='Include all domains (default).')
    parser.add_argument('-ap', '--apache-domains', action='store_true', help='Include Apache domains.')
    parser.add_argument('-ng', '--nginx-domains', action='store_true', help='Include Nginx domains.')
    parser.add_argument('-ha', '--haproxy-domains', action='store_true', help='Include HaProxy domains.')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print warnings to stdout.')
    args = parser.parse_args()

    global do_verbose_print
    do_verbose_print = args.verbose

    if args.action not in ['check-dns', 'list']:
        if args.output_style == 'nrpe':
            print('UNKNOWN - unknown {} action, use -h option for help.'.format(args.action))
            sys.exit(3)
        else:
            print('Unknown {} action, use -h option for help.'.format(args.action))
            sys.exit(1)

    doms = {}

    if not (args.apache_domains or args.nginx_domains or args.haproxy_domains):
        args.all_domains = True

    if args.all_domains:
        doms.update(list_apache_domains())
        doms.update(list_nginx_domains())
        doms.update(list_haproxy_acl_domains())
        doms.update(list_haproxy_certs_domains())

    else:
        if args.apache_domains:
            print('Apache domains')
            doms.update(list_apache_domains())
        if args.nginx_domains:
            print('Nginx domains')
            doms.update(list_nginx_domains())
        if args.haproxy_domains:
            print('HaProxy domains')
            doms.update(list_haproxy_acl_domains())
            #doms.update(list_haproxy_certs_domains())

    if not doms:
        if args.output_style == 'nrpe':
            print('UNKNOWN - No domain found on this server.')
            sys.exit(3)
        else: # == 'json' or 'human'
            print('No domain found on this server.')
            sys.exit(1)

    if args.action == 'check-dns':

        # Add included domains to domains dict
        with open(included_domains_path, encoding='utf-8') as f:
            line_number = 0
            for line in f:
                line_number += 1
                domain = strip_comments(line).strip() 
                if not domain: continue
                if domain not in doms:
                    doms[domain] = []
                doms[domain].append('{}:{}:{}'.format(program_name, included_domains_path, line_number))

        timeout_domains, none_domains, outside_ips, ok_domains = run_check_domains(doms.keys())

        if args.output_style == 'nrpe':
            output_nrpe_mode(timeout_domains, none_domains, outside_ips, ok_domains)

        elif args.output_style == 'json':
            print('Option --output-style json not implemented yet for action check-dns.')

        else:  # args.output_style == 'human'
            output_human_mode(doms, timeout_domains, none_domains, outside_ips)

    elif args.action == 'list':
        # Note: do not use domains include and exclude lists for listing.

        if args.output_style == 'nrpe':
            print('Action list is not available for --output-style nrpe.')

        elif args.output_style == 'json':
            print(json.dumps(doms, sort_keys=True, indent=4))

        else:
            print('Option --output-style human not implemented yet for action list, fallback to --output-style json.')
            print(json.dumps(doms, sort_keys=True, indent=4))

    #elif args.action == 'brice_action':
    #    #doms est un dict avec le nom de domaine comme clé, pour voir la structure de données :
    #    # domains --output-style json list
    #
    #    print(doms)
    #    brice_function(doms)
    #

if __name__ == '__main__':
    program_name = os.path.splitext(os.path.basename(__file__))[0]

    if 'cryptography.x509' not in sys.modules:
        print('Not supported: {} requires cryptography module.'.format(program_name))

    main(sys.argv[1:])

