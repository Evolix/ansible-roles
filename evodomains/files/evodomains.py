#!/usr/bin/python3
#
# Execute 'evodomains --help' for usage.
#
# Evodomains is a Python script to ease the management of a server's domains.
#
# Features:
# - Search for domains in Apache, Nginx and SSL certificates.
# - Check domains DNS A record.
#
# Roadmap :
# - Remove domains from vhosts configuration
# - Remove certificate files
# - Someday support HaProxy domains (with limitations like regex ACLs)
#
# Authors: Will
#

import os
import sys
import re
import subprocess
import threading
import time
import argparse
import json
import shutil
from enum import Enum
from typing import Type, List

# Not used yet because not available in Debian <= 8
#try:
#    from cryptography import x509
#    from cryptography.hazmat.primitives import hashes
#    from cryptography.hazmat.backends import default_backend
#    from cryptography.x509.oid import NameOID, ExtensionOID
#except:
#    pass


""" Constants """

config_dir_path = '/etc/evolinux/evodomains'
ignored_domains_file = 'ignored_domains_check.list'
included_domains_file = 'included_domains_check.list'
allowed_ips_file = 'allowed_ips_check.list'
wildcard_replacements_file = 'wildcard_replacements'
#haproxy_conf_path = '/etc/haproxy/haproxy.cfg'
ip_regex = re.compile('^([0-9abcdef\.:]+)$')
domain_regex = re.compile('^(((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})$')
wildcard_regex = re.compile('^(\*\.((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})$')
domain_cn_regex = re.compile('CN=(((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')
domain_san_regex = re.compile('DNS:(((?!-)[A-Za-z0-9-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')

# Time to wait for DNS answer before considering a domain has timeout.
# Note: DNS check of all domains must be <10s to avoid Icinga timeout.
DNS_timeout = 5


""" Global vars """

dep_openssl = False


""" Data structures """

class DomainSource:
    """Abstract class to store the infos about where a domain was found.
    For inheritance only, should not be instantiated.
    Attributes:
        - domain: the domain or subdomain
        - source:
            - 'apache', 'nginx', 'certbot', 'evoacme'
            - 'evodomains' : from evodomains configuration (included_domains_check.list)
            - 'manual' : from a manual certificate
        - type: type of source ('config', 'certificate')
        - path: config or certificate path where the domain was found
        - line: line in config file or certificate where the domain was found
        - port: listening port
        - attribute: certificate attribute ('CN', 'SAN')
    """
    def __init__(self, domain: str, source: str, source_type: str, path: str, line: int, port: int, attribute: str):
        self.domain = domain
        self.source = source
        self.type = source_type
        self.path = path
        self.line = line
        self.port = port
        self.attribute = attribute

    def __str__(self):
        return str(self.__dict__)

    def __eq__(self, other):
        if not isinstance(other, DomainSource):
            return False

        return (self.domain == other.domain
                and self.source == other.source
                and self.type == other.type
                and self.path == other.path
                and self.line == other.line
                and self.port == other.port
                and self.attribute == other.attribute
               )

class DomainSummary:
    """Data structure to contain infos about a domain and its DNS test results."""
    def __init__(self, domain: str, replacement_domain: str = None):
        self.domain = domain
        self.replacement_domain = replacement_domain
        self.sources = []
        self.DNS_check_result = None

    def add_source(self, source: Type[DomainSource]):
        self.sources.append(source)

    def add_sources(self, sources: List[Type[DomainSource]]):
        self.sources.extend(sources)

    def set_DNS_check_result(self, DNS_check_result):
        self.DNS_check_result = DNS_check_result


class EvodomainSource(DomainSource):
    """DomainSource for domains from included_domains_file."""
    def __init__(self, domain: str, path=None, line=None, port=None, attribute=None):
        if not path:
            path = os.path.join(config_dir_path, included_domains_file)
        super().__init__(domain, 'evodomains', 'config', path, line, port, attribute)

class ApacheSource(DomainSource):
    """DomainSource for Apache."""
    def __init__(self, domain: str, path: str, line: int, port: int, attribute=None):
        super().__init__(domain, 'apache', 'config', path, line, port, attribute)

class NginxSource(DomainSource):
    """DomainSource for Nginx."""
    def __init__(self, domain: str, path: str, line: int, port: int, attribute=None):
        super().__init__(domain, 'nginx', 'config', path, line, port, attribute)

class CertificateSource(DomainSource):
    """DomainSource for X.509 certificates."""
    def __init__(self, domain: str, source: str, path: str, attribute: str):
        super().__init__(domain, source, 'certificate', path, None, None, attribute)

#class HaProxySource(DomainSource):
#    """DomainSource for HaProxy."""
#    def __init__(self, domain, source_type, path, line, port=None, attribute=None):
#        super().__init__(domain, 'haproxy', source_type, path, line, port, attribute)


class CheckStatus(Enum):
    """DNS answer status"""
    OK = 1
    ERROR = 2
    DNS_TIMEOUT = 3
    NO_DNS_RECORD = 4
    UNKNOWN_IPS = 5


class DNSCheckResult:
    def __init__(self):
        self.status = CheckStatus.ERROR  # default to error if set_status() not called
        self.known_ips = {}  # { IP: reverse, … }
        self.unknown_ips = {}  # idem
        self.comments = []

    def set_status(self, status):
        if not isinstance(status, CheckStatus):
            raise ValueError('Unknown DNS status {}'.format(status))
        self.status = status

    def add_ip(self, ip, reverse, known):
        value = reverse if reverse else ip
        if known:
            self.known_ips[ip] = reverse
        else:
            self.unknown_ips[ip] = ip

    def add_comment(self, comment: str):
        """Argument 'comment' must be a simple sentence,
        without capital letter nor dot at the end.
        All comments will be concatenated, separated by commas.
        """
        self.comments.append(comment)


class CustomJSONEncoder(json.JSONEncoder):
    """Custom JSONEncoder that also encodes DomainSource objects as JSON."""
    def default(self, object):
        if isinstance(object, DomainSummary) or isinstance(object, DomainSource) or isinstance(object, DNSCheckResult):
            # Remove None values
            d = { key:value for key, value in object.__dict__.items() if value }
            return d
        elif isinstance(object, CheckStatus):
            return object.name
        else:
            return json.JSONEncoder.default(self, object)



""" Utilitary functions """


def print_error_and_exit(s):
    if output == 'nrpe':
        print('UNKNOWN - {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(3)
    else:
        print('Error: {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(1)

def print_warning(s):
    if warning and output != 'nrpe':
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


def strip_comments(string: str):
    """Return string with any # comment removed."""
    return string.split('#')[0]


def get_main_domain(domain: str):
    """Return main domain without subdomain.
    Example:
    - input 'www.example.com' will return 'example.com'.
    """
    splitted = domain.strip('.').split('.')[-2:]
    return '.'.join(splitted)


def get_sub_domain(domain: str):
    """Return subdomain without main domain.
    Example:
    - input 'dev.www.example.com' will return 'dev.www'.
    """
    splitted = domain.strip('.').split('.')[:-2]
    return '.'.join(splitted)


def sorted_domains(domains: List[str]):
    """Returns the list sorted by main domain (and not sub-domain)."""
    s = sorted(domains, key=get_sub_domain)
    return sorted(s, key=get_main_domain)


#def merge_dicts(*dicts):
#    """Merge an arbitrary number of dictionaries containing lists."""
#    merged = {}
#    for d in dicts:
#        for key, value in d.items():
#            merged.setdefault(key, []).extend(value)
#    return merged



""" Functions to deal with DNS resolution """


def dig(domain):
    """Return 'dig +short DOMAIN', as a list of lines."""
    stdout, stderr, rc = execute('dig +short {}'.format(domain))
    return stdout


class DNSResolutionThread(threading.Thread):
    """Thread that executes a dig."""

    def __init__(self, domain_summary):
        threading.Thread.__init__(self, daemon=True)
        self.domain_summary = domain_summary
        self.exception = ''
        self.ips = {}

    def run(self):
        """Resolve domain with dig."""
        try:
            domain = self.domain_summary.domain

            # Wilcards handling: check www.example.com for *.example.com
            if '*' in domain:
                if self.domain_summary.replacement_domain:
                    domain = self.domain_summary.replacement_domain
                else:
                    domain = domain.replace('*', 'www')

            dig_results = dig(domain)

            if not dig_results:
                return

            for line in dig_results:
                match = ip_regex.search(line)
                if match:
                    ip = match.group(1)
                    if ip not in self.ips:
                        self.ips[ip] = ''

            # Reverse
            for ip in self.ips:
                if not numeric:
                    dig_results = dig('-x ' + ip)
                    for line in dig_results:
                        match = re.search('^([0-9a-z\.-]+)$', line)
                        if match:
                            reverse = match.group(1).rstrip('.')
                            self.ips[ip] = reverse
                if not self.ips[ip]:
                    self.ips[ip] = ip

        except Exception as e:
            self.exception = e



""" Functions to deal with program config """


def read_config_file(file_path):
    """Return a list of not empty lines and without the comments (as strings)."""
    open(file_path, 'a').close()  # touch, in case of missing file

    cleaned_lines = []
    with open(file_path, encoding='utf-8') as f:
        for line in f:
            cleaned_line = strip_comments(line).strip()
            if not cleaned_line: continue
            cleaned_lines.append(cleaned_line)
    return cleaned_lines


def load_allowed_ips(allowed_ips_path):
    """Return the list of IPs the domains are allowed to point to, from configuration file."""
    # Server IPs
    stdout, stderr, rc = execute('hostname -I')
    if not stdout:
        return []
    allowed_ips = stdout[0].strip().split()

    # Read allowed IPs in config file
    conf_ips = read_config_file(allowed_ips_path)

    for ip in conf_ips:
        if ip_regex.search(ip):
            allowed_ips.append(ip)
        else:
            print_warning('Malformed IP {} in {}'.format(ip, allowed_ips_path))

    return allowed_ips


def load_wildcard_replacements(wildcard_replacements_path):
    """Return a dict containing wildcard domains as keys, and replacement domains as values,
    from configuration file.
    """
    wildcard_replacement_lines = read_config_file(wildcard_replacements_path)

    wildcard_replacements = {}
    for line in wildcard_replacement_lines:
        words = line.split()
        if len(words) != 2:
            print_warning('Malformed configuration line \'{}\' in {}. Two domains expected.'.format(line, wildcard_replacements_path))
        else:
            match = wildcard_regex.search(words[0])
            if match:
                wildcard = match.group(1)
            else:
                print_warning('Malformed wildcard \'{}\' in {}'.format(words[0], wildcard_replacements_path))
                continue

            match = domain_regex.search(words[1])
            if match:
                wildcard_replacement = match.group(1)
            else:
                print_warning('Malformed wildcard replacement \'{}\' in {}'.format(words[1], wildcard_replacements_path))
                continue

            wildcard_replacements[wildcard] = wildcard_replacement

    return wildcard_replacements



""" Functions to deal with X.509 certificates """


def is_certbot():
    """Return True if /etc/letsencrypt/live is not empty."""
    certbot_live_path = '/etc/letsencrypt/live'
    if not os.path.exists(certbot_live_path):
        return False
    certs = os.listdir(certbot_live_path)
    return len(certs) > 0


def get_certificate_domains(cert_path, source):
    """List the domains in the certificate with OpenSSL binary
    (Python module cryptography.x509 is not available on Debian <= 8).
    Return a list of CertificateSource.
    """
    sources = []
    if not os.path.exists(cert_path) or not os.path.isfile(cert_path):
        return sources

    command = 'openssl x509 -text -noout -in {}'.format(cert_path)
    try:
        stdout, stderr, rc = execute(command)
        if stderr:
            raise RuntimeError('{}\n'.format(command) + '\n'.join(stderr))
    except:
        print_debug('Could not read certificate file {} or execute {}.'.format(cert_path, command))
        return sources

    for line in stdout:
        if 'Subject:' in line:
            # CN
            # Format: subject: (...), CN=<COMMON NAME>, (...)
            match = domain_cn_regex.search(line)
            if match:
                domain = match.group(1)
                p = CertificateSource(domain, source, cert_path , 'CN')
                sources.append(p)

        if 'DNS:' in line:
            # SAN
            # format: DNS:<DOMAIN1>, DNS:<DOMAIN2>[, ...]
            matches = domain_san_regex.findall(line)
            for m in matches:
                domain = m[0]
                p = CertificateSource(domain, source, cert_path , 'SAN')
                sources.append(p)

    return sources



""" Print and output functions """


def output_domain_sources_human(domain_summary, prefix='', suffix=''):
    """Print domain sources of DomainSummary object in human readable format."""
    for p in domain_summary.sources:
        if p.source in ['apache', 'nginx'] and p.type in ['config']:
            print('{}{}:{} port(s) {}{}'.format(prefix, p.path, p.line, p.port, suffix))
        elif p.source in ['certbot', 'evoacme', 'manual'] and p.type in ['certificate']:
            print('{}{}:{}{}'.format(prefix, p.path, p.attribute, suffix))
        elif p.source in ['evodomains'] and p.type in ['config']:
            print('{}{}{}'.format(prefix, p.path, suffix))
        else:
            print('{}Unknown source {}{}'.format(prefix, p, suffix))


def output_comments_human(domain_summary, prefix='', suffix=''):
    """Print comments of DomainSummary object in human readable format."""
    for comment in domain_summary.DNS_check_result.comments:
        print('{}{}{}'.format(prefix, comment + '.', suffix))


def output_domain_summaries_json(domain_summaries):
    """Print domain_summaries dict to stdout in JSON format."""
    print(json.dumps(domain_summaries, sort_keys=True, indent=4, cls=CustomJSONEncoder))


def output_domain_summaries_human(domain_summaries):
    """Print domain_summaries dict to stdout in human readable format."""
    for domain_summary in sorted_domains(domain_summaries.keys()):
        print('{}'.format(domain_summary))
        output_domain_sources_human(domain_summaries[domain_summary], prefix='  ')


def output_check_result_nrpe(domain_summaries):
    """Print DNS check results to stdout in NRPE format.
    For now, never output critical alerts.
    """
    # Filter domains in function of check results
    ok_domains = dict(filter(filter_ok_domains, domain_summaries.items()))
    timeout_domains = dict(filter(filter_timeout_domains, domain_summaries.items()))
    no_dns_record_domains = dict(filter(filter_no_dns_record_domains, domain_summaries.items()))
    unknown_ips_domains = dict(filter(filter_unknown_ips_domains, domain_summaries.items()))
    error_domains = dict(filter(filter_error_domains, domain_summaries.items()))

    n_ok = len(ok_domains)
    n_warnings = len(timeout_domains) + len(no_dns_record_domains) + len(unknown_ips_domains)
    n_errors = len(error_domains)

    msg = 'WARNING' if n_warnings or n_errors else 'OK'

    print('{} - {} UNK / 0 CRIT / {} WARN / {} OK \n'.format(msg, n_errors, n_warnings, n_ok))

    for domain in sorted_domains(error_domains.keys()):
        comments = ''
        if domain_summaries[domain].DNS_check_result.comments:
            comments = ' (' + ', '.join(domain_summaries[domain].DNS_check_result.comments).lower() + ')'
        print('UNKNOWN - DNS status of {}{}'.format(domain, comments))

    for domain in sorted_domains(timeout_domains.keys()):
        comments = ''
        comments = ' (' + ', '.join(domain_summaries[domain].DNS_check_result.comments).lower() + ')' if domain_summaries[domain].DNS_check_result.comments else ''
        print('WARNING - timeout resolving {}{}'.format(domain, comments))

    for domain in sorted_domains(no_dns_record_domains.keys()):
        comments = ''
        if domain_summaries[domain].DNS_check_result.comments:
            comments = ' (' + ', '.join(domain_summaries[domain].DNS_check_result.comments).lower() + ')'
        print('WARNING - no DNS record for {}{}'.format(domain, comments))

    for domain in sorted_domains(unknown_ips_domains.keys()):
        unknown_ips = ', '.join(unknown_ips_domains[domain].DNS_check_result.unknown_ips.values())
        known_ips = ', '.join(unknown_ips_domains[domain].DNS_check_result.known_ips.values())
        comments = ''
        if domain_summaries[domain].DNS_check_result.comments:
            comments = ' (' + ', '.join(domain_summaries[domain].DNS_check_result.comments).lower() + ')'
        if known_ips:
            print('WARNING - {} resolves to unknown IP(s): {} and known IPs:{}{}'.format(domain, unknown_ips, known_ips, comments))
        else:
            print('WARNING - {} resolves to unknown IP(s): {}{}'.format(domain, unknown_ips, comments))

    if verbose:
        for domain in sorted_domains(ok_domains.keys()):
            known_ips = ', '.join(ok_domains[domain].DNS_check_result.known_ips.values())
            comments = ''
            if domain_summaries[domain].DNS_check_result.comments:
                comments = ' (' + ', '.join(domain_summaries[domain].DNS_check_result.comments).lower() + ')'
            if known_ips:
                print('OK - {} resolves to known IP(s): {}{}'.format(domain, known_ips, comments))
            else:  # case domain is in ignored domains list
                print('OK - {}{}'.format(domain, comments))

    sys.exit(1) if n_warnings or n_errors else sys.exit(0)


def output_check_result_json(domain_summaries):
    """Print result of check domains to stdout in JSON format."""
    # Filter domains in function of check results
    ok_domains = dict(filter(filter_ok_domains, domain_summaries.items()))
    timeout_domains = dict(filter(filter_timeout_domains, domain_summaries.items()))
    no_dns_record_domains = dict(filter(filter_no_dns_record_domains, domain_summaries.items()))
    unknown_ips_domains = dict(filter(filter_unknown_ips_domains, domain_summaries.items()))
    error_domains = dict(filter(filter_error_domains, domain_summaries.items()))

    unknown_ips_domains_output_dict = {}
    for domain in sorted_domains(unknown_ips_domains.keys()):
        unknown_ips = unknown_ips_domains[domain].DNS_check_result.unknown_ips.values()
        known_ips = unknown_ips_domains[domain].DNS_check_result.known_ips.values()
        unknown_ips_domains_output_dict[domain] = {}
        if known_ips:
            unknown_ips_domains_output_dict[domain]['unknown_ips'] = sorted(unknown_ips)
            unknown_ips_domains_output_dict[domain]['known_ips'] = sorted(known_ips)
        else:
            unknown_ips_domains_output_dict[domain] = sorted(unknown_ips)


    if verbose:
        ok_domains_output_dict = {}
        for domain in sorted_domains(ok_domains.keys()):
            known_ips = ok_domains[domain].DNS_check_result.known_ips.values()
            ok_domains_output_dict[domain] = sorted(known_ips)

    output_dict = {
        'timeout_domains': sorted_domains(timeout_domains.keys()),
        'no_dns_record_domains': sorted_domains(no_dns_record_domains.keys()),
        'error_domains': sorted_domains(error_domains.keys()),
        'unknown_ips_domains': unknown_ips_domains_output_dict
    }
    if verbose:
        output_dict['ok_domains'] = ok_domains_output_dict
        output_dict['details'] = domain_summaries

    print(json.dumps(output_dict, sort_keys=True, indent=4, cls=CustomJSONEncoder))


def output_check_result_human(domain_summaries):
    """Print result of check domains to stdout in human readable format."""
    # Filter domains in function of check results
    ok_domains = dict(filter(filter_ok_domains, domain_summaries.items()))
    timeout_domains = dict(filter(filter_timeout_domains, domain_summaries.items()))
    no_dns_record_domains = dict(filter(filter_no_dns_record_domains, domain_summaries.items()))
    unknown_ips_domains = dict(filter(filter_unknown_ips_domains, domain_summaries.items()))
    error_domains = dict(filter(filter_error_domains, domain_summaries.items()))

    if verbose and ok_domains:
        print('\nOK DNS:')
        for domain in sorted_domains(ok_domains.keys()):
            known_ips = ', '.join(ok_domains[domain].DNS_check_result.known_ips.values())
            print('  {} -> [{}]'.format(domain, known_ips))
            output_comments_human(domain_summaries[domain], '    Comment(s): ')
            output_domain_sources_human(domain_summaries[domain], '    ')

    if timeout_domains or no_dns_record_domains or unknown_ips_domains or error_domains:

        if timeout_domains:
            print('\nDNS timeouts:')
            for domain in sorted_domains(timeout_domains.keys()):
                print('  {}'.format(domain))
                output_comments_human(domain_summaries[domain], '    Comment(s): ')
                output_domain_sources_human(domain_summaries[domain], '    ')

        if no_dns_record_domains:
            print('\nNo DNS record:')
            for domain in sorted_domains(no_dns_record_domains.keys()):
                print('  {}'.format(domain))
                output_comments_human(domain_summaries[domain], '    Comment(s): ')
                output_domain_sources_human(domain_summaries[domain], '    ')

        if unknown_ips_domains:
            print('\nUnknown resolved IPs:')
            for domain in sorted_domains(unknown_ips_domains.keys()):
                unknown_ips = ', '.join(unknown_ips_domains[domain].DNS_check_result.unknown_ips.values())
                output_str = '  {} -> unknown [{}]'.format(domain, unknown_ips)
                known_ips = unknown_ips_domains[domain].DNS_check_result.known_ips.values()
                if known_ips:
                    known_ips = ', '.join(known_ips)
                    output_str += ', known [{}]'.format(domain, known_ips)
                print(output_str)
                output_comments_human(domain_summaries[domain], '    Comment(s): ')
                output_domain_sources_human(domain_summaries[domain], '    ')

        if error_domains:
            print('\nDNS error:')
            for domain in sorted_domains(error_domains.keys()):
                print('  {}'.format(domain))
                output_comments_human(domain_summaries[domain], '    Comment(s): ')
                output_domain_sources_human(domain_summaries[domain], '    ')

        sys.exit(1)

    else:
        print('Domains resolve to right IPs!')



""" Core functions """


def list_apache_domains():
    """Parse Apache live vhosts in search of domains.
    Return a list of ApacheSource.
    """
    print_debug('Listing Apache domains.')
    sources = []

    # Dumps Apache vhosts
    try:
        stdout, stderr, rc = execute('apache2ctl -D DUMP_VHOSTS')
    except:
        print_debug('Apache is not present.')
        return sources

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
                source = ApacheSource(domain, config_path, line_number, port)
                if source not in sources:
                    sources.append(source)

    return sources


def list_nginx_domains():
    """Parse Nginx dynamic config in search of domains.
    Return a list of NginxSource.
    """
    print_debug('Listing Ningx domains.')
    sources = []

    try:
        stdout, stderr, rc = execute('nginx -T')
    except:
        print_debug('Nginx is not present.')
        return sources

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
                                source = NginxSource(domain, config_file_path, line_number, port)
                                if source not in sources:
                                    sources.append(source)
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
                        if domain in ['_', 'localhost']:  # default vhosh
                            continue
                        domains.append(domain)

    # Save last server directive
    if domains and ports:
        for domain in domains:
            for port in ports:
                source = NginxSource(domain, config_file_path, line_number, port)
                if source not in sources:
                    sources.append(source)

    return sources


def list_certificates_domains(dir_path, source):
    """ Parse certificates in dir_path in search of domains (not recursive).
    Return a list of CertificateSource."
    """

    print_debug('Listing {} certificates domains for source {}.'.format(dir_path, source))
    if not dep_openssl:
        print_debug('OpenSSL not installed, passing.')
        return []

    sources = []

    if not os.path.exists(dir_path):
        return sources

    for f in os.listdir(dir_path):
        cert_path = os.path.join(dir_path, f)
        if os.path.islink(cert_path):
            # Cert is a CA
            continue

        cert_sources = get_certificate_domains(cert_path, source)
        if cert_sources:
            sources.extend(cert_sources)

    return sources


def list_letsencrypt_domains():
    """ Parse certificates in /etc/letsencrypt in search of domains.
    Return a list of CertificateSource."
    """
    print_debug('Listing Let\'s Encrypt certificates domains.')
    if not dep_openssl:
        print_debug('OpenSSL not installed, passing.')
        return []

    sources = []

    if is_certbot():
        source = 'certbot'
        base_path = '/etc/letsencrypt/live'
        subdir = ''
        cert_name = 'cert.pem'
    else:
        source = 'evoacme'
        base_path = '/etc/letsencrypt'
        subdir = 'live'
        cert_name = 'cert.crt'

    if not os.path.exists(base_path):
        return sources

    for dir_name in os.listdir(base_path):
        cert_path = os.path.join(base_path, dir_name, subdir, cert_name)
        cert_sources = get_certificate_domains(cert_path, source)
        if cert_sources:
            sources.extend(cert_sources)

    return sources


#def list_haproxy_acl_domains():
#    """Parse HaProxy config file in search of domain ACLs or files containing list of domains.
#    Return a dict containing :
#    - key: HaProxy domains (from ACLs in /etc/haproxy/haproxy.cgf).
#    - value: a list of strings 'haproxy:/etc/haproxy/haproxy.cfg:<LINE_IN_CONF>'
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
#def read_haproxy_domains_file(domains_file_path, source):
#    """Process a file containing a list of domains :
#    - domains_file_path: path of the file to parse
#    - source: string keyword to prepend to the domains infos. Exemple: 'haproxy'
#    Return a dict containing :
#    - key: domain (from domains_file_path)
#    - value: a list of strings 'source:domains_file_path:<LINE_IN_BLOCK>'
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
#                dom_infos = '{}:{}:{}'.format(source, domains_file_path, line_number)
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
#    - value: a list of strings 'haproxy_certs:cert_path:CN|SAN'
#    """
#    print_debug('Listing HaProxy certificates domains')
#    domains = {}
#
#    # Check if HaProxy version supports 'show ssl cert' command
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
#            print('hap certs', cert_paths)
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
#def list_cert_domains(cert_path, source):
#    """Return the domains present in a X.509 PEM certificate.
#    - cert_path: path of the certificate
#    - source: string keyword to prepend to the domains infos. Exemple: 'haproxy_certs'
#    Return a dict containing :
#    - key: domain (from the certificate)
#    - value: a list of strings 'source:cert_path:CN|SAN'
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
#           dom_infos = '{}:{}:CN'.format(source, cert_path)
#           if dom not in domains:
#               domains[dom] = []
#           if dom_infos not in domains[dom]:
#               domains[dom].append(dom_infos)
#
#        # Subject Alternative Name
#        try:
#            san_ext = cert.extensions.get_extension_for_oid(ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
#            for dom in san_ext.value.get_values_for_type(x509.DNSName):
#                dom_infos = '{}:{}:SAN'.format(source, cert_path)
#                if dom not in domains:
#                    domains[dom] = []
#                if dom_infos not in domains[dom]:
#                    domains[dom].append(dom_infos)
#        except x509.ExtensionNotFound:
#            pass
#
#    return domains


def list_domains():
    """List domains from all sources.
    Return a dict { key: domain, value: DomainSummary object }
    """
    apache_sources = list_apache_domains()
    nginx_sources = list_nginx_domains()
    letsencrypt_sources = list_letsencrypt_domains()
    etc_ssl_certs_sources = list_certificates_domains('/etc/ssl/certs', 'manual')
    #haproxy_acl_sources = list_haproxy_acl_domains()
    #haproxy_certs_sources = list_haproxy_certs_domains()

    sources = apache_sources + nginx_sources + letsencrypt_sources + etc_ssl_certs_sources

    for domain in evodomain_domains:
        source = EvodomainSource(domain)
        if source not in sources:
            sources.append(source)

    if not sources:
        print_error_and_exit('No domain found on this server.')

    domains = {}
    for p in sources:
        if p.domain not in domains:
            wildcard_replacement = ''
            if '*' in p.domain:
                if p.domain in wildcard_replacements:
                    wildcard_replacement = wildcard_replacements[p.domain]
                else:
                    wildcard_replacements_path = os.path.join(config_dir_path, wildcard_replacements_file)
                    print_warning('Wildcard {} has no replacement domain configured in {}'.format(p.domain, wildcard_replacements_path))
            domains[p.domain] = DomainSummary(p.domain, wildcard_replacement)
        domains[p.domain].add_source(p)

    return domains


def check_domains(domain_summaries):
    """Check resolution of domains and save it in a DNSCheckResult object
    in DomainSummary attribute DNS_check_result.
    Returns: nothing
    """
    jobs = []
    for domain, domain_summary in domain_summaries.items():
        t = DNSResolutionThread(domain_summary)
        t.start()
        jobs.append(t)

    # Let <DNS_timeout> secs to DNS servers to reply to jobs threads queries
    time.sleep(DNS_timeout)

    for job in jobs:
        result = DNSCheckResult()

        if '*' in job.domain_summary.domain:
            if job.domain_summary.replacement_domain:
                result.add_comment('resolution of {} checked on {}'.format(job.domain_summary.domain, job.domain_summary.replacement_domain))
            else:
                result.add_comment('resolution of {} checked on subdomain www'.format(job.domain_summary.domain))

        for ip in job.ips:
            result.add_ip(ip, job.ips[ip], ip in allowed_ips)

        if job.is_alive():
            result.set_status(CheckStatus.DNS_TIMEOUT)
        elif not job.ips:
            result.set_status(CheckStatus.NO_DNS_RECORD)
        elif result.unknown_ips:
            result.set_status(CheckStatus.UNKNOWN_IPS)
        else:
            result.set_status(CheckStatus.OK)

        if job.domain_summary.domain in ignored_domains:
            result.set_status(CheckStatus.OK)
            result.add_comment('domain is in ignored domains list')

        if job.exception:
            result.set_status(CheckStatus.ERROR)
            result.add_comment('exception occured during dig: {}'.format(str(result.exception)))

        job.domain_summary.set_DNS_check_result(result)


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', metavar='ACTION', help='Values: check-dns, list')
    parser.add_argument('-d', '--debug', action='store_true', help='Print debug to stderr and enable --verbose.')
    parser.add_argument('-n', '--numeric', action='store_true', help='Show only IPs, no reverse DNS.')
    parser.add_argument('-o', '--output', default='human', help='Output format. Values: human (default), json, nrpe (only with check-dns action)')
    parser.add_argument('-s', '--no-warnings', action='store_true', help='Silence warnings (useful for --output json).')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print more output to stdout.')
    args = parser.parse_args()

    global action, debug, numeric, output, warning, verbose
    action = args.action
    debug = args.debug
    numeric = args.numeric
    output = args.output
    warning = not args.no_warnings
    verbose = args.verbose
    verbose = true if debug else args.verbose

    for arg, value in vars(args).items():
        print_debug('{} = {}'.format(arg, value))

    if action not in ['check-dns', 'list']:
        print_error_and_exit('Unknown {} action, use -h option for help.'.format(args.action))

    if output not in ['human', 'json', 'nrpe']:
        err_msg = 'Unknown {} argument for --output option.'.format(output)
        print_error_and_exit(err_msg)


def check_deps():
    #TODO: socat for HaProxy

    if shutil.which('openssl'):
        dep_openssl = True
    else:
        print_warning('Missing \'openssl\' dependency, cannot list nor check certificates domains.')

    # Lib cryptography.x509 is more pythonic than OpenSSL, but not used for now because not available on Debian <= 8
    # We don't want to maintain 2 ways of reading certs).
    # See get_certificate_domains().
    #if 'cryptography.x509' not in sys.modules:
    #    print_warning('Python3 cryptography.x509 module missing (need python3-cryptography >= 0.9), failing over OpenSSL binary.')


def load_conf():
    # Create missing directories and files
    if not os.path.exists(config_dir_path):
        os.makedirs(config_dir_path, mode=0o755, exist_ok=True)
    ignored_domains_path = os.path.join(config_dir_path, ignored_domains_file)
    included_domains_path = os.path.join(config_dir_path, included_domains_file)
    allowed_ips_path = os.path.join(config_dir_path, allowed_ips_file)
    wildcard_replacements_path = os.path.join(config_dir_path, wildcard_replacements_file)
    for f in [ignored_domains_path, included_domains_path, allowed_ips_path, wildcard_replacements_path]:
        open(f, 'a').close()  # touch, in case of missing file

    # Load config in global variables
    global ignored_domains, evodomain_domains, allowed_ips, wildcard_replacements
    ignored_domains = read_config_file(ignored_domains_path)
    evodomain_domains = read_config_file(included_domains_path)
    allowed_ips = load_allowed_ips(allowed_ips_path)
    wildcard_replacements = load_wildcard_replacements(wildcard_replacements_path)

    ignored_domains.append('_')

def filter_ok_domains(pair):
    domain_name, domain_obj = pair
    return domain_obj.DNS_check_result.status == CheckStatus.OK

def filter_timeout_domains(pair):
    domain_name, domain_obj = pair
    return domain_obj.DNS_check_result.status == CheckStatus.DNS_TIMEOUT

def filter_no_dns_record_domains(pair):
    domain_name, domain_obj = pair
    return domain_obj.DNS_check_result.status == CheckStatus.NO_DNS_RECORD

def filter_unknown_ips_domains(pair):
    domain_name, domain_obj = pair
    return domain_obj.DNS_check_result.status == CheckStatus.UNKNOWN_IPS

def filter_error_domains(pair):
    domain_name, domain_obj = pair
    return domain_obj.DNS_check_result.status == CheckStatus.ERROR


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
        elif output == 'human':
            output_domains_human(domains)

    elif action == 'check-dns':
        check_domains(domains)

        if output == 'nrpe':
            output_check_result_nrpe(domains)
        elif output == 'json':
            output_check_result_json(domains)
        elif output == 'human':
            output_check_result_human(domains)


if __name__ == '__main__':
    program_name = os.path.splitext(os.path.basename(__file__))[0]
    main(sys.argv[1:])

