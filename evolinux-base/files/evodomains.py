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

import os
import sys
import re
import subprocess
import threading
import time
import argparse
import json
from enum import Enum
try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.backends import default_backend
    from cryptography.x509.oid import NameOID, ExtensionOID
except:
    pass


config_dir_path = '/etc/evolinux/domains'
ignored_domains_file = 'ignored_domains_check.list'
included_domains_file = 'included_domains_check.list'
allowed_ips_file = 'allowed_ips_check.list'
haproxy_conf_path = '/etc/haproxy/haproxy.cfg'
domain_cn_regex = re.compile('CN=(((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')
domain_san_regex = re.compile('DNS:(((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')

# Time to wait for DNS answer before considering a domain in timeouted.
# (Full DNS check must execute in less than 10s to avoid Icinga timeout.)
DNS_timeout = 5


""" Data structures """

class Domain:
    def __init__(self, domain):
        self.domain = domain
        self.providers = []
        self.DNS_check_result = None

    def add_provider(self, provider):
        self.providers.append(provider)

    def add_providers(self, providers):
        self.providers.extend(providers)

    def set_DNS_check_result(self, DNS_check_result):
        self.DNS_check_result = DNS_check_result


class DomainProvider:
    """Data structure to store where a domain was found.
    For inheritance only, should not be instantiated.
    Attributes:
        - domain: the domain
        - provider: 'apache', 'nginx', 'x509', 'haproxy', ''
        - type: type of provider ('config', 'certificate')
        - path: config or certificate path where the domain was found
        - line: line in config file or certificate where the domain was found
        - port: listening port
        - attribute: certificate attribute ('CN', 'SAN')
    """
    def __init__(self, domain, provider, provider_type, path, line, port, attribute):
        self.domain = domain
        self.provider = provider
        self.type = provider_type
        self.path = path
        self.line = line
        self.port = port
        self.attribute = attribute

    def __str__(self):
        return str(self.__dict__)

    def __eq__(self, other):
        if not isinstance(other, DomainProvider):
            return False

        return (self.domain == other.domain
                and self.provider == other.provider
                and self.type == other.type
                and self.path == other.path
                and self.line == other.line
                and self.port == other.port
                and self.attribute == other.attribute
               )

class IncludedProvider(DomainProvider):
    """DomainProvider for domains from included_domains_file."""
    def __init__(self, domain, path=None, line=None, port=None, attribute=None):
        if not path:
            path = os.path.join(config_dir_path, included_domains_file)
        super().__init__(domain, 'evodomains', 'config', path, line, port, attribute)

class ApacheProvider(DomainProvider):
    """DomainProvider for Apache."""
    def __init__(self, domain, path, line, port, attribute=None):
        super().__init__(domain, 'apache', 'config', path, line, port, attribute)

class NginxProvider(DomainProvider):
    """DomainProvider for Nginx."""
    def __init__(self, domain, path, line, port, attribute=None):
        super().__init__(domain, 'nginx', 'config', path, line, port, attribute)

class CertificateProvider(DomainProvider):
    """DomainProvider for X.509 certificates."""
    def __init__(self, domain, provider, path, attribute):
        super().__init__(domain, provider, 'certificate', path, None, None, attribute)

#class HaProxyProvider(DomainProvider):
#    """DomainProvider for HaProxy."""
#    def __init__(self, domain, provider_type, path, line, port=None, attribute=None):
#        super().__init__(domain, 'haproxy', provider_type, path, line, port, attribute)


class CheckStatus(Enum):
    OK = 1
    UNKNOWN = 2
    DNS_TIMEOUT = 3
    DOMAIN_NOT_FOUND = 4
    IP_NOT_ALLOWED = 5


class DNSCheckResult:
    def __init__(self):
        self.status = CheckStatus.UNKNOWN
        self.resolve_ips = []
        self.comments = []

    def set_status(self, status):
        if not isinstance(status, CheckStatus):
            raise ValueError('Unknown DNS status {}'.format(status))
        self.status = status

    def set_resolve_ips(self, ips):
        self.resolve_ips = ips

    def add_comment(self, comment):
        self.comments.append(comment)


class CustomJSONEncoder(json.JSONEncoder):
    """Custom JSONEncoder that also encodes DomainProvider objects
    as JSON.
    """
    def default(self, object):
        if isinstance(object, Domain) or isinstance(object, DomainProvider) or isinstance(object, DNSCheckResult):
            # Remove None values
            d = { key:value for key, value in object.__dict__.items() if value }
            return d
        elif isinstance(object, CheckStatus):
            return object.name
        else:
            return json.JSONEncoder.default(self, object)



""" Utilitary functions """


def print_error_and_exit(s):
    if output ==  'nrpe':
        print('UNKNOWN - {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(3)
    else:
        print('Error: {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(1)

def print_warning(s):
    if warning or debug:
        print('Warning: {}'.format(s), file=sys.stderr, flush=True)

def print_debug(s):
    if debug:
        print('Debug: {}'.format(s), flush=True)


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


def strip_comments(string):
    """Return string with any # comment removed.""" 
    return string.split('#')[0]


#def merge_dicts(*dicts):
#    """Merge an arbitrary number of dictionaries containing lists."""
#    merged = {}
#    for d in dicts:
#        for key, value in d.items():
#            merged.setdefault(key, []).extend(value)
#    return merged



""" Code to deal with DNS resolution """


def dig(domain):
    """Return "dig +short $domain", as a list of lines."""
    stdout, stderr, rc = execute('dig +short {}'.format(domain))
    return stdout


class DNSResolutionThread(threading.Thread):
    """Thread that executes a dig."""

    def __init__(self, domain):
        threading.Thread.__init__(self, daemon=True)
        self.domain = domain
        self.ips = []

    def run(self):
        """Resolve domain with dig."""
        try:
            domain = self.domain.domain
            # Wilcards hanling: check www.example.com for *.example.com
            if '*' in domain:
                domain = domain.replace('*', 'www')

            dig_results = dig(domain)

            if not dig_results:
                return

            for line in dig_results:
                match = re.search('^([0-9abcdef\.:]+)$', line)
                if match:
                    ip = match.group(1)
                    if ip not in self.ips:
                        self.ips.append(ip)

        except Exception as e:
            print_warning(e)
            return



""" Functions to deal with program config """


def read_config_file(file_path):
    """Return a list of not empty lines and without the comments (as strings).
    """
    cleaned_lines = []
    with open(file_path, encoding='utf-8') as f:
        for line in f:
            cleaned_line = strip_comments(line).strip()
            if not cleaned_line: continue
            cleaned_lines.append(cleaned_line)
    return cleaned_lines


def get_allowed_ips():
    """Return the list of IPs the domains are allowed to point to.
    """

    # Server IPs
    stdout, stderr, rc = execute('hostname -I')
    if not stdout:
        return []
    ips = stdout[0].strip().split()

    # Read custom allowed IPs in config file
    allowed_ips_path = os.path.join(config_dir_path, allowed_ips_file)
    ips.extend(read_config_file(allowed_ips_path))

    return ips



""" Functions to deal with X.509 certificates """


def get_certificate_domains(cert_path, provider):
    """List the domains in the certificate with OpenSSL binary
    (Python module cryptography.x509 is not available on Debian 8).
    Return a list of CertificateProvider."
    """
    providers = []
    if not os.path.exists(cert_path) or not os.path.isfile(cert_path):
        return providers

    command = 'openssl x509 -text -noout -in {}'.format(cert_path)
    try:
        stdout, stderr, rc = execute(command)
        if stderr:
            raise RuntimeError('{}\n'.format(command) + '\n'.join(stderr))
    except:
        print_debug('Could not read certificate file {} or execute {}.'.format(cert_path, command))
        return providers

    for line in stdout:
        if 'Subject:' in line:
            # CN
            # Format: subject: (...), CN=<COMMON NAME>, (...)
            match = domain_cn_regex.search(line)
            if match:
                domain = match.group(1)
                p = CertificateProvider(domain, provider, cert_path , 'CN')
                providers.append(p)

        if 'DNS:' in line:
            # SAN
            # format: DNS:<DOMAIN1>, DNS:<DOMAIN2>[, ...]
            matches = domain_san_regex.findall(line)
            for m in matches:
                domain = m[0]
                p = CertificateProvider(domain, provider, cert_path , 'SAN')
                providers.append(p)

    return providers



""" Print and output functions """


def output_domains_json(domains):
    """Print domains dict to stdout in JSON format.
    """
    print(json.dumps(domains, sort_keys=True, indent=4, cls=CustomJSONEncoder))


def output_domains_human(domains):
    """Print domains dict to stdout in human readable format.
    """
    for dom in sorted(domains.keys()):
        print('{}'.format(dom))
        output_providers_human(domains[dom], prefix='\t')


def output_check_result_nrpe(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains):
    """Print DNS check results to stdout in NRPE format.
    For now, never output critical alerts.
    """
    n_ok = len(ok_domains)
    n_warnings = len(timeout_domains) + len(not_found_domains) + len(unallowed_domains)
    n_unknown = len(unknown_domains)

    msg = 'WARNING' if n_warnings or n_unknown else 'OK'

    print('{} - {} UNK / 0 CRIT / {} WARN / {} OK \n'.format(msg, n_unknown, n_warnings, n_ok))

    for d in unknown_domains.keys():
        print('UNKNOWN - DNS status of {}'.format(d))
    for d in timeout_domains.keys():
        print('WARNING - timeout resolving {}'.format(d))
    for d in not_found_domains.keys():
        print('WARNING - no resolution for {}'.format(d))
    for d in unallowed_domains.keys():
        print('WARNING - {} resolves to unallowed IP ({})'.format(d, ' '.join(unallowed_domains[d].DNS_check_result.resolve_ips)))

    sys.exit(1) if n_warnings or n_unknown else sys.exit(0)


def output_check_result_json(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains):
    """Print result of check domains to stdout in JSON format.
    """
    output_dict = {
        'timeout_domains': sorted(timeout_domains),
        'not_found_domains': sorted(not_found_domains),
        'unallowed_domains': unallowed_domains,
        'unknown_domains': unknown_domains,
        'ok_domains': sorted(ok_domains),
        'domains': domains
    }
    print(json.dumps(output_dict, sort_keys=True, indent=4, cls=CustomJSONEncoder))


def output_providers_human(domain, prefix='', suffix=''):
    """Print providers of domain object in human readable format.
    """
    for p in domain.providers:
        if p.provider in ['apache', 'nginx'] and p.type in ['config']:
            print('{}{}:{} port(s) {}{}'.format(prefix, p.path, p.line, p.port, suffix))
        elif p.provider in ['letsencrypt'] and p.type in ['certificate']:
            print('{}{}:{}{}'.format(prefix, p.path, p.attribute, suffix))
        elif p.provider in ['manual'] and p.type in ['certificate']:
            print('{}{}:{}{}'.format(prefix, p.path, p.attribute, suffix))
        elif p.provider in ['evodomains'] and p.type in ['config']:
            print('{}{}{}'.format(prefix, p.path, suffix))
        else:
            print('{}Unknown provider {}{}'.format(prefix, p, suffix))


def output_check_result_human(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains):
    """Print result of check domains to stdout in human readable format.
    """
    if timeout_domains or not_found_domains or unallowed_domains or unknown_domains:

        if timeout_domains: print('\nTimeouts:')
        for d in timeout_domains.keys():
            print('\t{}'.format(d))
            output_providers_human(domains[d], '\t\t')

        if not_found_domains: print('\nNo resolution:')
        for d in not_found_domains.keys():
            print('\t{}'.format(d))
            output_providers_human(domains[d], '\t\t')

        if unallowed_domains: print('\nUnallowed resolved IPs:')
        for d in unallowed_domains.keys():
            print('\t{} -> [{}]'.format(d, ' '.join(unallowed_domains[d].DNS_check_result.resolve_ips)))
            output_providers_human(domains[d], '\t\t')

        if unknown_domains: print('\nUnknown DNS status:')
        for d in unknown_domains.keys():
            print('\t{}'.format(d))
            output_providers_human(domains[d], '\t\t')

        sys.exit(1)

    print('Domains resolve to right IPs!')



""" Core functions """


def list_apache_domains():
    """Parse Apache live vhosts in search of domains.
    Return a list of ApacheProvider.
    """
    print_debug('Listing Apache domains.')
    providers = []

    # Dumps Apache vhosts
    try:
        stdout, stderr, rc = execute('apache2ctl -D DUMP_VHOSTS')
    except:
        print_debug('Apache is not present.')
        return providers

    # Parse output of 'apache2ctl -D DUMP_VHOSTS'
    for line in stdout:
        domain = ''
        words = line.strip().split()

        if 'namevhost' in line and len(words) >= 5:
            # line format: port <PORT> namevhost <DOMAIN> (<VHOST_PATH>:<VHOST_LINE_NUMBER>)
            port = int(words[1])
            domain = words[3].strip()
            config_path, vhost_line_number = words[4].strip('()').split(':')
            vhost_line_number = int(vhost_line_number)

        elif 'alias' in line and len(words) >= 2:
            # line format: alias <DOMAIN>
            domain = words[1].strip()  # other infos defined upward ^

        if domain:
            # Find line numbers in config file
            # (limit search inside <VirtualHost> directives)
            line_numbers = []
            with open(config_path, encoding='utf-8') as f:
                i = 0
                for line in f:
                    i += 1
                    if i < vhost_line_number:
                        continue
                    line = strip_comments(line).strip()
                    if i > vhost_line_number and line == '</VirtualHost>':
                        break

                    if 'ServerName' in line or 'ServerAlias' in line:
                        words = line.split()
                        if 'ServerName' in words or 'ServerAlias' in words:
                            if domain in words:
                                line_numbers.append(i)

            for line_number in line_numbers:
                provider = ApacheProvider(domain, config_path, line_number, port)
                if provider not in providers:
                    providers.append(provider)

    return providers


def list_nginx_domains():
    """Parse Nginx dynamic config in search of domains.
    Return a list of NginxProvider.
    """
    print_debug('Listing Ningx domains.')
    providers = []

    try:
        stdout, stderr, rc = execute('nginx -T')
    except:
        print_debug('Nginx is not present.')
        return providers

    line_number, config_file_path, ports, domains = None, None, None, None

    for line in stdout:
        if line_number is not None:
            line_number += 1

        # New config file, reset line number
        if '# configuration file' in line:
            # line format: # configuration file <PATH>:
            words = line.strip().strip(';').split()
            config_file_path = words[3].strip(' :')
            line_number = 0

        else:
            line = strip_comments(line).strip()

            # New vhost, save previous result and reset domains and ports
            if 'server' in line and '{' in line:
                # line format: server {
                line = strip_comments(line).strip().strip('{').strip()
                if line == 'server':
                    if domains and ports:
                        for domain in domains:
                            for port in ports:
                                provider = NginxProvider(domain, config_file_path, line_number, port)
                                if provider not in providers:
                                    providers.append(provider)
                    domains, ports = [], []

            # Parse port
            elif 'listen' in line:
                # line format: [IP:]<PORT> [[IP:]<PORT>...] | <OTHER_DIRECTIVES>
                line = strip_comments(line).strip().strip(';')
                words = line.split()

                if 'listen' in words:
                    for w1 in words[1:]:
                        words2 = w1.split(':')
                        for w2 in words2:
                            try:
                                p = int(w2)
                            except:
                                # Not a port
                                pass
                            else:
                                if p not in ports:
                                    ports.append(p)

            # Parse domain
            elif 'server_name' in line:
                # line format: server_name <DOMAIN1> [<DOMAINS2 ...];
                line = strip_comments(line).strip().strip(';')
                words = line.split()

                if 'server_name' in words:
                    for d in words[1:]:
                        domain = d.strip()
                        if domain == '_':  # default vhost
                            continue
                        domains.append(domain)

    # Save last server directive
    if domains and ports:
        for domain in domains:
            for port in ports:
                provider = NginxProvider(domain, config_file_path, line_number, port)
                if provider not in providers:
                    providers.append(provider)

    return providers


def list_certificates_domains(dir_path, provider):
    """ Parse certificates in dir_path in search of domains (not recursive).
    Return a list of CertificateProvider."
    """

    print_debug('Listing {} certificates domains for provider {}.'.format(dir_path, provider))
    providers = []

    if not os.path.exists(dir_path):
        return providers

    for f in os.listdir(dir_path):
        cert_path = os.path.join(dir_path, f)
        if os.path.islink(cert_path):
            # Cert is a CA
            continue

        cert_providers = get_certificate_domains(cert_path, provider)
        if cert_providers:
            providers.extend(cert_providers)

    return providers


def list_letsencrypt_domains():
    """ Parse certificates in /etc/letsencrypt in search of domains.
    Return a list of CertificateProvider."
    """
    print_debug('Listing Let\'s Encrypt certificates domains.')
    providers = []

    le_path = '/etc/letsencrypt'
    if not os.path.exists(le_path):
        return providers

    for vhost in os.listdir(le_path):
        cert_path = os.path.join(le_path, vhost, 'live', 'cert.crt')
        cert_providers = get_certificate_domains(cert_path, 'letsencrypt')
        if cert_providers:
            providers.extend(cert_providers)

    return providers


#def list_haproxy_acl_domains():
#    """Parse HaProxy config file in search of domain ACLs or files containing list of domains.
#    Return a dict containing :
#    - key: HaProxy domains (from ACLs in /etc/haproxy/haproxy.cgf).
#    - value: a list of strings "haproxy:/etc/haproxy/haproxy.cfg:<LINE_IN_CONF>"
#    """
#    print_debug('Listing HaProxy ACL domains')
#    domains = {}
#
#    if not os.path.isfile(haproxy_conf_path):
#        # HaProxy is not installed
#        print_warning('{} not found'.format(haproxy_conf_path))
#        return domains
#
#    # Domains from ACLs
#    with open(haproxy_conf_path, encoding='utf-8') as f:
#        line_number = 0
#        files = []
#        for line in f.readlines():
#            line_number += 1
#
#            # Handled line format:
#            #    acl <ACL_NAME> [hdr|hdr_reg|hdr_end](host) [-i] <STRING> [<STRING> [...]]
#            #    acl <ACL_NAME> [hdr|hdr_reg](host) [-i] -f <FILE>
#
#            line = strip_comments(line).strip()
#
#            if (not line) or (not line.startswith('acl')):
#                continue
#            if 'hdr(host)' not in line and 'hdr_reg(host)' not in line and 'hdr_end(host)' not in line:
#                continue
#
#            # Remove 'acl <ACL_NAME>' from line
#            line = ' '.join(line.split()[2:])
#
#            is_file = False
#            if ' -f ' in line:
#                is_file = True
#
#            # Limit: does not handle regex
#
#            words = line.split()
#            for word in line.split():
#                if word in ['hdr(host)', 'hdr_reg(host)', 'hdr_end(host)', '-f', '-i']:
#                    continue
#
#                if is_file:
#                    if word not in files:
#                        print('Found HaProxy domains file {}'.format(word))
#                        files.append(word)
#                else:
#                    dom_infos = 'haproxy:{}:{}'.format(haproxy_conf_path, line_number)
#                    if word not in domains:
#                        domains[word] = []
#                    if dom_infos not in domains[word]:
#                        domains[word].append(dom_infos)
#
#        for f in files:
#            domains_to_add = read_haproxy_domains_file(f, 'haproxy')
#            domains.update(domains_to_add)
#
##TODO remove (call elsewhere)
#    # Domains from HaProxy certificates
##    domains_to_add = list_haproxy_certs_domains()
##    domains.update(domains_to_add)
#
#    return domains
#
#
#def read_haproxy_domains_file(domains_file_path, origin):
#    """Process a file containing a list of domains :
#    - domains_file_path: path of the file to parse
#    - origin: string keyword to prepend to the domains infos. Exemple: 'haproxy'
#    Return a dict containing :
#    - key: domain (from domains_file_path)
#    - value: a list of strings "origin:domains_file_path:<LINE_IN_BLOCK>"
#    """
#    domains = {}
#
#    try:
#        with open(domains_file_path, encoding='utf-8') as f:
#            line_number = 0
#            for line in f.readlines():
#                line_number += 1
#
#                dom = strip_comments(line).strip()
#                if not dom:
#                    continue
#
#                dom_infos = '{}:{}:{}'.format(origin, domains_file_path, line_number)
#                if dom not in domains:
#                    domains[dom] = []
#                if dom_infos not in domains[dom]:
#                    domains[dom].append(dom_infos)
#
#    except FileNotFoundError as e:
#        print_warning('FileNotFound {}'.format(domains_file_path))
#        print_warning(e)
#
#    return domains
#
#
#def list_haproxy_certs_domains():
#    """Return the domains present in HaProxy SSL certificates.
#    Return a dict containing:
#    - key: domain (from domains_file_path)
#    - value: a list of strings "haproxy_certs:cert_path:CN|SAN"
#    """
#    print_debug('Listing HaProxy certificates domains')
#    domains = {}
#
#    # Check if HaProxy version supports "show ssl cert" command
#    supports_show_ssl_cert = does_haproxy_support_show_ssl_cert()
#
#    if supports_show_ssl_cert:
#        socket = get_haproxy_stats_socket()
#        # Ajoute l'IP locale dans le cas d'un port TCP (au lieu d'un socket Unix)
#        if socket.startswith(':'):
#            socket = 'tcp:127.0.0.1{}'.format(socket)
#
#        print('echo "show ssl cert" | socat stdio {}'.format(socket))
#        stdout, stderr, rc = execute('echo "show ssl cert" | socat stdio {}'.format(socket), shell=True)
#
#        for cert_path in stdout:
#            if cert_path.strip().startswith('#'):
#                continue
#            if os.path.isfile(cert_path):
#                domains_to_add = list_cert_domains(cert_path, 'haproxy_certs')
#                domains.update(domains_to_add)
#
#    else:
#        if not os.path.isfile(haproxy_conf_path):
#            # HaProxy is not installed
#            print_warning('{} not found'.format(haproxy_conf_path))
#            return domains
#
#        # Get HaProxy certificates paths (can be directory or file)
#        # Line format : bind *:<PORT> ssl crt <CERT_PATH>
#        cert_paths = []
#        with open(haproxy_conf_path, encoding='utf-8') as f:
#            for line in f.readlines():
#                line = strip_comments(line).strip()
#                if not line: continue
#                if ' crt ' in line:
#                    crt_index = line.find(' crt ')
#                    subs = line[crt_index+5:]
#                    cert_path = subs.split(' ')[0]  # in case other options are after cert path
#                    cert_paths.append(cert_path)
#            print("hap certs", cert_paths)
#
#        for cert_path in cert_paths:
#            if os.path.isfile(cert_path):
#                print(cert_path)
#                domains_to_add = list_cert_domains(cert_path, 'haproxy_certs')
#                domains.update(domains_to_add)
#            elif os.path.isdir(cert_path):
#                for f in os.listdir(cert_path):
#                    p = cert_path + f
#                    if os.path.isfile(p):
#                        domains_to_add = list_cert_domains(p, 'haproxy_certs')
#                        domains.update(domains_to_add)
#
#    return domains
#
#
#def does_haproxy_support_show_ssl_cert():
#    """Return True if HaProxy version supports 'show ssl cert' command (version >= 2.2)."""
#
#    stdout, stderr, rc = execute('dpkg -l haproxy | grep ii', shell=True)
#
#    supports_show_ssl_cert = False
#
#    if rc == 0:
#        for line in stdout:
#            words = line.strip().split()
#            if len(words) >= 3 and words[1] == 'haproxy':
#                version = words[2]
#                [major, minor] = version.split('.')[:2]
#                if int(major) >= 2 and int(minor) >= 2:
#                    supports_show_ssl_cert = True
#
#    return supports_show_ssl_cert
#
#
#def get_haproxy_stats_socket():
#    """Return HaProxy stats socket."""
#
#    with open(haproxy_conf_path, encoding='utf-8') as f:
#        line_number = 0
#        for line in f.readlines():
#            words = line.strip().split()
#            if len(words) >= 3 and words[0] == 'stats' and words[1] == 'socket':
#                i
#                return words[2]
#
#    return None
#
#
#def list_cert_domains(cert_path, origin):
#    """Return the domains present in a X.509 PEM certificate.
#    - cert_path: path of the certificate
#    - origin: string keyword to prepend to the domains infos. Exemple: 'haproxy_certs'
#    Return a dict containing :
#    - key: domain (from the certificate)
#    - value: a list of strings "origin:cert_path:CN|SAN"
#    """
#    domains = {}
#
#    with open(cert_path, 'rb') as f:
#        try:
#            cert = x509.load_pem_x509_certificate(f.read(), default_backend())
#        except ValueError:
#            print_warning('Could not load certificate file {}.'.format(cert_path))
#            return domains
#
#        # Common name
#        cn_list = cert.subject.get_attributes_for_oid(NameOID.COMMON_NAME)
#        if cn_list and len(cn_list) > 0:
#           dom = cn_list[0].value
#           dom_infos = '{}:{}:CN'.format(origin, cert_path)
#           if dom not in domains:
#               domains[dom] = []
#           if dom_infos not in domains[dom]:
#               domains[dom].append(dom_infos)
#
#        # Subject Alternative Name
#        try:
#            san_ext = cert.extensions.get_extension_for_oid(ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
#            for dom in san_ext.value.get_values_for_type(x509.DNSName):
#                dom_infos = '{}:{}:SAN'.format(origin, cert_path)
#                if dom not in domains:
#                    domains[dom] = []
#                if dom_infos not in domains[dom]:
#                    domains[dom].append(dom_infos)
#        except x509.ExtensionNotFound:
#            pass
#
#    return domains


def list_domains():
    """List domains from all providers.
    Return a dict of { key: domain, value: Domain object }
    """
    apache_providers = list_apache_domains()
    nginx_providers = list_nginx_domains()
    letsencrypt_providers = list_letsencrypt_domains()
    etc_ssl_certs_providers = list_certificates_domains('/etc/ssl/certs', 'manual')
    #haproxy_acl_providers = list_haproxy_acl_domains()
    #haproxy_certs_providers = list_haproxy_certs_domains()

    providers = apache_providers + nginx_providers + letsencrypt_providers + etc_ssl_certs_providers

    for domain in included_domains:
        provider = IncludedProvider()
        if provider not in providers:
            providers.append(provider)

    if not providers:
        print_error_and_exit('No domain found on this server.')

    domains = {}
    for p in providers:
        if p.domain not in domains:
            domains[p.domain] = Domain(p.domain)
        domains[p.domain].add_provider(p)

    return domains


def check_domains(domains):
    """Check resolution of domains and save it a DNSCheckResult object in Domain attribute DNS_check_result.
    Returns: nothing
    #- timeout_domains: list of domains which exceeded timeout limit (see 'timeout' variable).
    #- none_domains: list of domains that do not resolve.
    #- outside_ips: dict of domains (keys) that resolve to some not allowed IPs (values).
    #- ok_domains: list of domains that resolve to allowed IPs.
    """
    jobs = []
    for domain_txt, domain_obj in domains.items():
        t = DNSResolutionThread(domain_obj)
        t.start()
        jobs.append(t)

    # Let <DNS_timeout> secs to DNS servers to reply to jobs threads queries
    time.sleep(DNS_timeout)

    for j in jobs:
        result = DNSCheckResult()

        if '*' in j.domain.domain:
            result.add_comment("Domain in ignored domains list.")

        if j.domain.domain in ignored_domains:
            result.set_status(CheckStatus.OK)
            result.add_comment("Domain in ignored domains list.")
            if j.ips:
                result.set_resolve_ips(j.ips)
        elif j.is_alive():
            result.set_status(CheckStatus.DNS_TIMEOUT)
        elif not j.ips:
            result.set_status(CheckStatus.DOMAIN_NOT_FOUND)
        else:
            result.set_resolve_ips(j.ips)
            is_allowed = True
            for ip in j.ips:
                if ip not in allowed_ips:
                    is_allowed = False
                    break
            if not is_allowed:
                result.set_status(CheckStatus.IP_NOT_ALLOWED)
            else:
                result.set_status(CheckStatus.OK)

        j.domain.set_DNS_check_result(result)


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', metavar='ACTION', help='Values: check-dns, list')
    parser.add_argument('-o', '--output', help='Output format. Values: human (default), json, nrpe')
    #parser.add_argument('-s', '--ssl-only', action='store_true', help='SSL/TLS domains only (not implemented.')
    parser.add_argument('-w', '--warning', action='store_true', help='Print warnings to stdout.')
    parser.add_argument('-d', '--debug', action='store_true', help='Print debug to stdout (include warnings).')
    args = parser.parse_args()

    global action, output, warning, debug #, ssl_only
    action = args.action
    output = args.output
    warning = args.warning
    debug = args.debug
    #ssl_only = args.ssl_only

    for arg, value in vars(args).items():
        print_debug('{} = {}'.format(arg, value))

    if action not in ['check-dns', 'list']:
        print_error_and_exit('Unknown {} action, use -h option for help.'.format(args.action))


def check_deps():
    #TODO: socat, openssl…
    # Replaced by openssl (for now, it is useless to maintain 2 ways of reading certs)
    #if 'cryptography.x509' not in sys.modules:
    #    print_warning('Python3 cryptography.x509 module missing (need python3-cryptography >= 0.9), failing over OpenSSL binary.')
    pass


def load_conf():
    # Create missing directories and files
    if not os.path.exists(config_dir_path):
        os.makedirs(config_dir_path, mode=0o755, exist_ok=True)
    ignored_domains_path = os.path.join(config_dir_path, ignored_domains_file)
    included_domains_path = os.path.join(config_dir_path, included_domains_file)
    allowed_ips_path = os.path.join(config_dir_path, allowed_ips_file)
    for f in [ignored_domains_path, included_domains_path, allowed_ips_path]:
        open(f, 'a').close()  # touch

    # Load config in global variables
    global ignored_domains, included_domains, allowed_ips
    ignored_domains = read_config_file(ignored_domains_path)
    included_domains = read_config_file(included_domains_path)
    allowed_ips = get_allowed_ips()

    ignored_domains.append('_')


def main(argv):
    parse_arguments()
    check_deps()
    load_conf()
    domains = list_domains()

    if action == 'list':
        if output == 'nrpe':
            print_error_and_exit('Action \'list\' is not available for \'--output nrpe\'.')
        elif output == 'json':
            output_domains_json(domains)
        else:  # output == 'human'
            output_domains_human(domains)

    elif action == 'check-dns':
        check_domains(domains)

        # Sort domains in function of check results
        ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains = {}, {}, {}, {}, {}
        for domain_txt, domain_obj in domains.items():
            if domain_obj.DNS_check_result.status == CheckStatus.OK:
                ok_domains[domain_txt] = domain_obj
            elif domain_obj.DNS_check_result.status == CheckStatus.DNS_TIMEOUT:
                timeout_domains[domain_txt] = domain_obj
            elif domain_obj.DNS_check_result.status == CheckStatus.DOMAIN_NOT_FOUND:
                not_found_domains[domain_txt] = domain_obj
            elif domain_obj.DNS_check_result.status == CheckStatus.IP_NOT_ALLOWED:
                unallowed_domains[domain_txt] = domain_obj
            elif domain_obj.DNS_check_result.status == CheckStatus.UNKNOWN:
                unknown_domains[domain_txt] = domain_obj
            else:
                unknown_domains[domain_txt] = domain_obj

        if output == 'nrpe':
            output_check_result_nrpe(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains)
        elif output == 'json':
            output_check_result_json(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains)
        else:  # output == 'human'
            output_check_result_human(domains, ok_domains, timeout_domains, not_found_domains, unallowed_domains, unknown_domains)


if __name__ == '__main__':
    program_name = os.path.splitext(os.path.basename(__file__))[0]
    main(sys.argv[1:])

