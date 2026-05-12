#!/usr/bin/python3
#
# Evodomains is tool to discover and check a server's domains and certificates.
#
# Execute 'evodomains --help' for usage.
#
# Features:
# - List domains in Apache and Nginx configuration, and in TLS certificates.
# - List certificates in Apache and Nginx configuration, /etc/ssl/, Certbot…
# - Check A DNS records.
# - Check certificates expiration.
# - Check if a certificate misses domains, compared to vhosts server names and alises.
#
# Minimal requirement: Debian 9
# Dependencies: python3-cryptography, python3-tabulate, python3-requests
# Author: Will


# Standard library

import argparse, os, pwd, grp, sys, shutil, tempfile, glob, uuid
import socket, ipaddress, ssl
import subprocess, multiprocessing.pool, threading
import re, json, operator
from datetime import datetime, timedelta, timezone
from typing import Type, List, Dict, Tuple, Callable
from enum import Enum
from urllib.parse import urlsplit

# Dependencies not in the standard library

try:
    from tabulate import tabulate
except:
    print('Missing tabulate module. Please install python3-tabulate package.', file=sys.stderr)
    exit(1)

try:
    import cryptography
except:
    print('Missing cryptography module. Please install python3-cryptography package.', file=sys.stderr)
    exit(1)
cryptography_major_version = int(cryptography.__version__.split('.')[0])
cryptography_handles_verification = cryptography_major_version > 43
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

try:
    import dns.resolver
    import dns.reversename
except:
    print('Missing dnspython module. Please install python3-dnspython package.', file=sys.stderr)
    exit(1)
dnspython_handles_resolve = False
if hasattr(dns, '__version__'):
    dnspython_major_version = int(dns.__version__.split('.')[0])
    dnspython_handles_resolve = dnspython_major_version >= 2

try:
    import requests
    # Disable InsecureRequestWarning (raised when requests gets a self-signed certificate)
    requests.packages.urllib3.disable_warnings()
except:
    print('Missing requests module. Please install python3-requests package.', file=sys.stderr)
    exit(1)


"""
Global vars
"""

version = '0.2.4'
conf_dir_path = '/etc/evolinux/evodomains'

haproxy_conf_path = '/etc/haproxy/haproxy.cfg'

# check-domains conf
ignored_domains_file = 'ignored_domains_check.list'
extra_domains_file = 'included_domains_check.list'
allowed_ips_file = 'allowed_ips_check.list'
wildcard_replacements_file = 'wildcard_replacements'
# Time to wait for DNS answer before considering a domain has timeout.
# Note: DNS check of all domains must be < 10s to avoid NRPE timeout.
DNS_timeout = 5

# challenge http conf
http_challenge_timeout = 5
http_challenge_dir = '/var/lib/letsencrypt/.well-known/acme-challenge'
http_challenge_uri = '.well-known/acme-challenge'

# check-certs conf
ignored_certs_file = 'ignored_certs_check.list'
extra_certs_file = 'included_certs_check.list'
default_exp_days_warn = 15
default_exp_days_crit = 7

# Regex
ip_regex = re.compile(r'^([0-9abcdef\.:]+)$')
domain_regex = re.compile(r'^(((?!-)[A-Za-z0-9\-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})$')
permissive_domain_regex = re.compile(r'^((?!-)[A-Za-z0-9\-\*\.]{1,255})$')
reverse_regex = re.compile(r'^(((?!-)[A-Za-z0-9\-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})\.$')
wildcard_regex = re.compile(r'^(\*\.((?!-)[A-Za-z0-9\-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})$')
# Match a wildcard domain followed by a domain (space separated)
wildcard_replacement_conf_regex = re.compile(r'^(\*\.(?:(?!-)[\-A-Za-z0-9]{1,63}(?<!-)\.)+[A-Za-z]{2,6})\s+((?:(?!-)[\-A-Za-z0-9]{1,63}(?<!-)\.)+[A-Za-z]{2,6})$')
domain_cn_regex = re.compile(r'CN\s*=\s*(((?!-)[A-Za-z0-9\-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')
domain_san_regex = re.compile(r'DNS:(((?!-)[A-Za-z0-9\-\*]{1,63}(?<!-)\.)+[A-Za-z]{2,6})')

# Dependencies (see check_dependencies())
pager = None
is_apache_mod_info = False



"""
Data classes
"""


class DomainSource:
    """ Abstract class to store the infos about where a domain was found.
    This class mustn't be instantiated, it is for inheritance only.
    Attributes:
        domain: the domain or subdomain
        roommates: other domains associated with domain in the same vhost or certificate
        source (suggested values):
            - 'apache', 'nginx', 'certbot', 'evoacme'
            - 'evodomains' : from evodomains configuration (extra_domains) on command-line
            - 'system_cert' : from /etc/ssl/certs/
            - 'custom_cert' : from --location option
        type: type of source ('conf_file', 'certificate', 'cli')
        path: conf file or certificate path where the domain was found
    """
    def __init__(self, domain: str, roommates: List[str], source: str, source_type: str, path: str):
        self.domain = domain
        self.roommates = roommates
        self.source = source
        self.type = source_type
        self.path = path

    def __str__(self):
        return str(self.__dict__)

    def __eq__(self, other):
        if not isinstance(other, DomainSource):
            return False

        return (self.domain == other.domain
                and self.source == other.source
                and self.type == other.type
                and self.path == other.path
                )


class ExtraDomainConfFileSource(DomainSource):
    """ DomainSource for domains from extra_domains_file.
    """
    def __init__(self, domain: str, line_number: int, path: str = None):
        if not path:
            path = os.path.join(conf_dir_path, extra_domains_file)
        self.line_numbers = [line_number]
        super().__init__(domain, [], 'evodomains', 'conf_file', path)


class EvodomainCommandLineSource(DomainSource):
    """ DomainSource for domains in command-line arguments.
    """
    def __init__(self, domain: str):
        super().__init__(domain, [], 'evodomains', 'cli', '')


class ApacheVhost:
    """ Represents an Apache vhost.
    Used for to parse the output of 'apache2ctl -t -D DUMP_VHOSTS'
    """
    def __init__(self, servername: str, path: str, port: int, start_line: int):
       self.servername = servername
       self.path = path
       self.port = port
       self.start_line = start_line
       self.aliases = []

    def __repr__(self):
        return str(self.__dict__)


class WebSource(DomainSource):
    """ DomainSource for Apache and Nginx.
    Attributes:
        line_numbers: list of line numbers of the occurences of domain in conf file
        ports: list of listening ports
        certificates: list of certificates paths
        intermediate_certificates: list of intermediate certificates paths (SSLCertificateChainFile deprecated in Apache, but still used)
        others: see DomainSource.
    """
    def __init__(self, domain: str, roommates: List[str], web_source: str, path: str):
        super().__init__(domain, roommates, web_source, 'conf_file', path)
        self.line_numbers = []
        self.ports = []
        self.certificates = []
        self.intermediate_certificates = []

    def add_line_number(self, line_number: int):
        if line_number not in self.line_numbers:
            self.line_numbers.append(line_number)

    def add_port(self, port: int):
        if port not in self.ports:
            self.ports.append(port)

    def add_certificate(self, cert_path):
        if cert_path not in self.certificates:
            self.certificates.append(cert_path)

    def add_intermediate_certificate(self, cert_path):
        if cert_path not in self.intermediate_certificates:
            self.intermediate_certificates.append(cert_path)

    def __eq__(self, other):
        if not isinstance(other, WebSource):
            return False

        return (super().__eq__(other)
                and sorted(self.line_numbers) == sorted(other.line_numbers)
                and sorted(self.ports) == sorted(other.ports)
                )


class OrderedEnum(Enum):
    """ Enum that can be compared with '<'.
    For sorting purposes.
    """
    def __lt__(self, other):
        if self.__class__ is other.__class__:
            return self.value < other.value
        raise NotImplementedError


class CertExpirationStatus(OrderedEnum):
    """ DNS answer status
    Note: Numbers are also used for sorting.
    """
    EXPIRED = 1
    EXPIRES_VERY_SOON = 2
    EXPIRES_SOON = 3
    OK = 4

    def __lt__(self, other):
        if self.__class__ is other.__class__:
            return self.value < other.value
        raise NotImplementedError


class CertCheckResult:
    def __init__(self, expiration_status: CertExpirationStatus):
        self.expiration_status = expiration_status
        self.not_covered_domains = []
        self.is_self_signed = False
        self.comments = []

    def add_not_covered_domain(self, domain: str):
        """ Add domain to the list not_covered_domains,
        which contains the domains that should have been covered by the certificate.
        """
        if domain not in self.not_covered_domains:
            self.not_covered_domains.append(domain)

    def add_comment(self, comment: str):
        """ Argument 'comment' must be a simple sentence,
        without capital letter nor dot at the end.
        All comments will be concatenated, separated by commas.
        """
        self.comments.append(comment)


class Certificate:
    """ Represent a certificate.
    """
    def __init__(self, path: str, common_names: List[str], alt_names: List[str], end_date: datetime, issuer: str):
        self.path = path
        self.common_names = sorted(common_names)
        self.alt_names = sorted(alt_names)
        self.end_date = end_date
        self.issuer = issuer
        self.vhost_path = None
        self.cert_check_result = None

    def set_cert_check_result(self, cert_check_result: CertCheckResult):
        self.cert_check_result = cert_check_result


class CertificateSource(DomainSource):
    """ DomainSource for X.509 certificates.
    Attributes:
        cert_attributes: list of certificate attribute ('CN', 'SAN')
    """
    def __init__(self, domain: str, roommates: List[str], source: str, path: str):
        super().__init__(domain, roommates, source, 'certificate', path)
        self.cert_attributes = []

    def add_cert_attribute(self, cert_attribute: int):
        self.cert_attributes.append(cert_attribute)

    def __eq__(self, other):
        if not isinstance(other, WebSource):
            return False

        return (super().__eq__(other)
                and sorted(self.cert_attributes) == sorted(other.cert_attributes)
                )


class DNSCheckStatus(OrderedEnum):
    """ DNS answer status.
    Note : Numbers are also used for sorting.
    """
    UNCHECKED = 1
    NO_DNS_RECORD = 2
    DNS_TIMEOUT = 3
    UNKNOWN_IPS = 4
    ERROR = 5
    OK = 6


class DNSCheckResult:
    def __init__(self, domain: str):
        self.domain = domain
        self.status = None
        self.allowed_ips = []  # { IP: reverse, … }
        self.allowed_ips_reverses = []
        self.unknown_ips = []
        self.unknown_ips_reverses = []
        self.comments = []

    def __eq__(self, other):
        """ Return True if other has the sames IPs and status.
        """
        if type(other) != type(self):
            return False

        return (set(other.allowed_ips) == set(self.allowed_ips)
            and set(other.unknown_ips) == set(self.unknown_ips)
            and other.status == self.status)

    def set_status(self, status: DNSCheckStatus):
        if not isinstance(status, DNSCheckStatus):
            raise ValueError('Unknown DNS status {}'.format(status))
        self.status = status

    def add_ip(self, ip: str, allowed: bool, reverse: str = None):
        if allowed:
            if ip not in self.allowed_ips:
                self.allowed_ips.append(ip)
            if reverse not in self.allowed_ips_reverses:
                self.allowed_ips_reverses.append(reverse)
        else:
            if ip not in self.unknown_ips:
                self.unknown_ips.append(ip)
            if reverse not in self.unknown_ips_reverses:
                self.unknown_ips_reverses.append(reverse)

    def add_comment(self, comment: str):
        """ Argument 'comment' must be a simple sentence,
        without capital letter nor dot at the end.
        All comments will be concatenated, separated by commas.
        """
        self.comments.append(comment)


class HTTPChallengeStatus(OrderedEnum):
    """ HTTP challenge status.
    Note : Numbers are also used for sorting.
    """
    ERROR = 1
    REQUEST_TIMEOUT = 2
    UNEXPECTED_HTTP_STATUS = 3
    UNCHECKED = 4
    IGNORED = 5
    SUCCESS = 6


class HTTPChallengeResult:
    def __init__(self, domain: str):
        self.domain = domain
        self.status = None
        self.http_status_code = None
        self.comments = []

    def set_status(self, status: HTTPChallengeStatus):
        if not isinstance(status, HTTPChallengeStatus):
            raise ValueError('Unknown HTTP challenge status {}'.format(status))
        self.status = status

    def add_comment(self, comment: str):
        """ Argument 'comment' must be a simple sentence,
        without capital letter nor dot at the end.
        All comments will be concatenated, separated by commas.
        """
        self.comments.append(comment)


class DomainSummary:
    """ Data structure that contains infos about a domain, its sources, and its DNS test results.
    """
    def __init__(self, domain: str, replacement_domain: str = None):
        self.domain = domain
        self.replacement_domain = replacement_domain  # for wildcards
        self.sources = []
        self.dns_check_result = None
        self.http_challenge_result = None

    def add_source(self, source: Type[DomainSource]):
        self.sources.append(source)

    def add_sources(self, sources: List[Type[DomainSource]]):
        self.sources.extend(sources)

    def set_dns_check_result(self, dns_check_result: DNSCheckResult):
        self.dns_check_result = dns_check_result

    def set_http_challenge_result(self, http_challenge_result: HTTPChallengeResult):
        self.http_challenge_result = http_challenge_result


class CustomJSONEncoder(json.JSONEncoder):
    """Encode in JSON usual types and classes defined by evodomains.
    """
    def default(self, obj):
        if (isinstance(obj, DomainSummary) or isinstance(obj, DomainSource)
                                              or isinstance(obj, HTTPChallengeResult)
                                              or isinstance(obj, DNSCheckResult)
                                              or isinstance(obj, Certificate)
                                              or isinstance(obj, ApacheVhost)
                                              or isinstance(obj, CertCheckResult)):
            # Remove None values
            d = { key:value for key, value in obj.__dict__.items() if value != None and value != [] }
            return d
        elif isinstance(obj, DNSCheckStatus) or isinstance(obj, HTTPChallengeStatus) or isinstance(obj, CertExpirationStatus):
            return obj.name
        elif isinstance(obj, datetime) or isinstance(obj, timedelta):
            return str(obj).split('.')[0]  # convert to string + remove millisecs
        else:
            return json.JSONEncoder.default(self, obj)



"""
General functions
"""


def main(argv):
    parse_arguments()
    check_versions()
    check_dependencies()
    load_configuration()

    domains_summaries = list_domains(locations)

    if action == 'list':
        if output == 'nrpe':
            print_error_and_exit('Action \'list\' is not available for \'--output nrpe\'.')
        if is_check_valid_domains:
            check_domains(domains_summaries)
        print_domains(domains_summaries, output)

    elif action == 'check-dns':
        if is_verbose and (output == 'json' or output == 'table'):
            print_allowed_ips()

        check_domains(domains_summaries)
        print_dns_check(domains_summaries, output)

    elif action in ['http-challenge']:
        if output == 'nrpe':
            print_error_and_exit('Action \'http-challenge\' is not available for \'--output nrpe\'.')
        check_domains(domains_summaries)
        challenge_domains(domains_summaries)
        print_challenge_results(domains_summaries, output)

    elif action in ['check-certs', 'check-ssl']:
        if is_check_valid_domains:
            check_domains(domains_summaries)
        certs = check_certificates(domains_summaries)
        print_certificates_check(certs, output)


def parse_arguments():
    parser = argparse.ArgumentParser(prog='evodomains')
    parser.add_argument('action', metavar='ACTION', nargs='?', choices=['help','list', 'check-dns', 'http-challenge', 'check-certs', 'check-ssl'], default='help',
        help="""Available actions: list: list the domains,
            check-dns: check the domains DNS,
            http-challenge: do HTTP challenges in local /var/lib/letsencrypt/.well-known/acme-challenge like Let\'s Encrypt (vhosts must be configured accordingly),
            check-certs: check the TLS certificates,
            help: show this help""")

    group = parser.add_mutually_exclusive_group()
    group.add_argument('domains', metavar='DOMAIN', nargs='*', default=[], help='Provide directly domain names for check-dns action. In this case, the domains discovery is skipped.')
    group.add_argument('-l', '--location', nargs='+', help='''Location(s) to search domains, space-separated.
        Values can be: 'apache', 'nginx', 'haproxy' (certificates only), 'certificates' (in /etc/ssl/certs, Haproxy, Certbot and Evoacme),
        'extra-domains' (listed in file /etc/evolinux/evodomains/extra-domains),
        'extra-certs' (listed in file /etc/evolinux/evodomains/extra-certs),
        a directory path (certificates only, not recursive) or an enabled vhost name.
        Default is 'apache nginx certificates extra-domains\'''')
    parser.add_argument('-d', '--debug', action='store_true', help='Print debug to stderr and enable --verbose')
    parser.add_argument('-r', '--reverse', action='store_true', help='Show reverse DNS instead of IPs')
    parser.add_argument('--no-pager', action='store_true', help='Do not pipe output into a pager')
    parser.add_argument('--no-header', action='store_true', help='Do not print header when default output (--output table)')
    parser.add_argument('--non-interactive', action='store_true', help='Run without confirmation messages and disable colors (implies --no-pager as well)')
    parser.add_argument('--color', action='store_true', help='Force color (that are desactivated with pipes, redirections or non-interactive shells)')
    parser.add_argument('-o', '--output', default='table', help='Output format, values: table (default), json, nrpe (only with check-dns and check-certs actions)')
    parser.add_argument('--expiration-warn', help='Threshold for certificate "expires soon" warning message, in days, default: 10')
    parser.add_argument('--expiration-crit', help='Threshold for certificate "expires very soon" critical message, in days, default: 7')
    parser.add_argument('--valid-domains', action='store_true', help='Check only certificates containing domains that are validated by check-dns action (only with check-certs action)')
    parser.add_argument('-q', '--no-warnings', action='store_true', help='Quiet, suppress warnings (useful for --output json)')
    parser.add_argument('-v', '--verbose', action='store_true', help='With check-dns, print also OK domains; with --output json, print details for each domain')
    parser.add_argument('-V', '--version', action='version', version='%(prog)s {}'.format(version))

    args = parser.parse_args()

    if args.action == 'help':
        parser.print_help()
        exit(0)

    global action, action_domains, output, locations, exp_days_warn, exp_days_crit, is_check_valid_domains
    global is_debug, is_numeric, is_warning, is_verbose, is_pager, is_header, is_interactive, is_color

    # Booleans
    is_debug = args.debug
    is_numeric = not args.reverse
    is_warning = not args.no_warnings
    is_verbose = True if is_debug else args.verbose
    is_pager = not args.no_pager
    is_header = not args.no_header
    is_color = args.color
    if args.non_interactive:
        is_interactive = False
    else:
        is_interactive = sys.__stdin__.isatty() and sys.__stdout__.isatty()

    print_debug('Command line arguments:')
    for arg, value in vars(args).items():
        print_debug('{} = {}'.format(arg, value))

    # Other args

    output = args.output
    if output not in ['table', 'json', 'nrpe']:
        err_msg = 'Unknown argument {} for --output option.'.format(output)
        print_error_and_exit(err_msg)

    action = args.action
    if action not in ['list', 'check-dns', 'http-challenge', 'check-certs', 'check-ssl']:
        print_error_and_exit('Unknown action {}, use -h option for help.'.format(action))
    action_domains = []
    for domain in args.domains:
        match = domain_regex.search(domain)
        if match and match.group(1):
            action_domains.append(match.group(1))
        else:
            print_error_and_exit('Argument {} is not a valid domain name.'.format(domain))

    if action_domains and action not in ['check-dns', 'http-challenge']:
        print_error_and_exit('DOMAIN argument is only relevant with actions check-dns or http-challenge ({}).'.format(', '.join(action_domains)))

    locations = args.location

    if action != 'check-certs' and (args.expiration_warn or args.expiration_crit):
        print_error_and_exit('Options --expiration-warn and --expiration-crit are exclusively for action check-certs')
    try:
        exp_days_warn = int(args.expiration_warn) if args.expiration_warn else default_exp_days_warn
        exp_days_crit = int(args.expiration_crit) if args.expiration_crit else default_exp_days_crit
    except:
        print_error_and_exit('Options --expiration-warn and --expiration-crit must be positive integers, use -h option for help.')
    if exp_days_warn < 0 or exp_days_crit < 0:
        print_error_and_exit('Options --expiration-warn and --expiration-crit must be positive integers, use -h option for help.')
    if exp_days_warn <= exp_days_crit:
        print_error_and_exit('Option --expiration-warn must be greater than --expiration-crit, use -h option for help.')

    exp_days_warn = timedelta(days=exp_days_warn)
    exp_days_crit = timedelta(days=exp_days_crit)

    if action not in ['check-certs', 'list'] and args.valid_domains:
        print_error_and_exit('Option --valid-domains is exclusively for actions list and check-certs')
    is_check_valid_domains = args.valid_domains

    print_debug('---')
    print_debug('Action requested: {}.'.format(action))
    print_debug('Search domains in: {}.'.format(locations))
    print_debug('Output in {} format.'.format(output))
    print_debug('Certificates warning thresholds: warning {} days, critical {} days.'.format(exp_days_warn, exp_days_crit))
    print_debug('---')



def check_versions():
    global ssl_protocol
    if sys.version_info.major >= 3 and sys.version_info.minor >= 6:
        ssl_protocol = ssl.PROTOCOL_TLS_CLIENT
    else:
        ssl_protocol = ssl.PROTOCOL_SSLv23


def check_dependencies():
    global is_pager, pager, is_apache_mod_info

    if 'PAGER' in os.environ and os.environ['PAGER']:
        pager = os.environ['PAGER']
    else:
        if shutil.which("less"):
            pager = 'less --no-init --quit-if-one-screen --chop-long-lines --RAW-CONTROL-CHARS'
        else:
            print_warning('Could not find \'less\', pager disabled. You can customize it with th PAGER environment variable.')
            pager = None
            is_pager = false

    try:
        stdout, stderr, rc = execute('apache2ctl -t -D DUMP_MODULES')
        for line in stdout:
            if 'info_module' in line.split():
                is_apache_mod_info = True
                break
        if not is_apache_mod_info and is_verbose:
            print('Apache mod_info is not enabled, using static configuration. To use it, you can enable it with \'a2enmod info\' (Apache restart needed)')
    except:
        pass


def load_configuration():
    # Create missing directories and files
    if not os.path.exists(conf_dir_path):
        os.makedirs(conf_dir_path, mode=0o755, exist_ok=True)

    # Load configuration in global variables

    global ignored_domains, extra_domains, allowed_ips, wildcard_replacements, extra_certs, ignored_certs

    ignored_domains = read_conf_file(conf_dir_path + '/' + ignored_domains_file, permissive_domain_regex)
    ignored_domains = [dom[0] for dom in ignored_domains]
    ignored_domains.append('_')

    replacements_tuples = read_conf_file(conf_dir_path + '/' + wildcard_replacements_file, wildcard_replacement_conf_regex)
    wildcard_replacements = {}
    for (wildcard, replacement) in replacements_tuples:
        wildcard_replacements[wildcard] = replacement

    ignored_certs = read_conf_file(conf_dir_path + '/' + ignored_certs_file)

    extra_domains_lines = read_conf_file(conf_dir_path + '/' + extra_domains_file, permissive_domain_regex)
    extra_domains = [ (i+1, extra_domains_lines[i][0]) for i in range(len(extra_domains_lines)) ] # trick to get also the domain line number

    extra_certs = read_conf_file(conf_dir_path + '/' + extra_certs_file)

    allowed_ips = read_conf_file(conf_dir_path + '/' + allowed_ips_file, ip_regex)
    allowed_ips = [ip for (ip,) in allowed_ips] # (ip,) unpacks a tuple of one element, the result of the regex match

    # Add host IPs to allowed_ips
    stdout, stderr, rc = execute('hostname -I')
    if stdout:
        host_ips = stdout[0].strip().split()
        allowed_ips.extend(host_ips)
    else:
        print_warning('Allow hostname IPs : command \'hostname -I\' returned no result.')


"""
Business logic : domains discovery
"""


class Location(Enum):
    APACHE = 'apache'
    NGINX = 'nginx'
    HAPROXY = 'haproxy' # certs only
    CERTIFICATES = 'certificates'
    EXTRA_DOMAINS = 'extra-domains'
    EXTRA_CERTS = 'extra-certs'


def list_domains(locations: List = []):
    """ List domains from all sources.
    Return a dict { key: domain, value: DomainSummary object }
    """
    sources = []

    if action_domains:
        # Domains are provided in command-line arguments
        for domain in action_domains:
            source = EvodomainCommandLineSource(domain)
            if source not in sources:
                sources.append(source)

    else:
        if not locations: # default
            locations = [Location.APACHE.value, Location.NGINX.value, Location.CERTIFICATES.value, Location.EXTRA_DOMAINS.value, Location.EXTRA_CERTS.value] # default

        # Add domains found in different locations
        for location in locations:
            if location == Location.APACHE.value:
                vhosts = parse_apache_dump_vhosts()
                sources += list_apache_domains(vhosts)
            elif location == Location.NGINX.value:
                sources += list_nginx_domains()
            elif location == Location.CERTIFICATES.value:
                sources += list_letsencrypt_domains()
                if os.path.isdir('/etc/ssl/certs'):
                    sources += list_certificates_domains('/etc/ssl/certs', 'system_cert')
                sources += list_haproxy_certificates_domains()
            elif location == Location.HAPROXY.value:
                sources += list_haproxy_certificates_domains()
            elif location == Location.EXTRA_DOMAINS.value:
                for (line_number, domain) in extra_domains:
                    source = ExtraDomainConfFileSource(domain, line_number)
                    if source not in sources:
                        sources.append(source)
            elif location == Location.EXTRA_CERTS.value:
                for cert in extra_certs:
                    sources += parse_certificate_domains(cert, 'evodomains')
            elif os.path.isdir(location):
                sources += list_certificates_domains(location, 'custom_cert')
            elif os.path.isfile(location):
                cert_sources = parse_certificate_domains(location, 'custom_cert')
                if not cert_sources:
                    print_error_and_exit('The file {} does not appear to be a certificate, or it contains no domain.'.format(location))
                sources += cert_sources
            else: # location == vhost name ?
                sources += list_vhost_domains(location)

        if not sources:
            print_error_and_exit('No domain found.')

    summaries = {}
    for source in sources:
        if source.domain not in summaries:
            summaries[source.domain] = DomainSummary(source.domain, replace_wildcard(source.domain))
        summaries[source.domain].add_source(source)

    for domain in summaries:
        remove_duplicate_certs(summaries[domain])

    return summaries


def replace_wildcard(wildcard: str):
    """ Return a replacement domain for a wildcard domain.
    If configuration has no replacement, print a warning and replace *.DOMAIN by www.DOMAIN
    """
    wildcard_replacement = ''
    if '*' in wildcard:
        if wildcard in wildcard_replacements:
            wildcard_replacement = wildcard_replacements[wildcard]
    return wildcard_replacement

def remove_duplicate_certs(summary: DomainSummary):
    """ Filter out certificates that are already used in vhosts,
    including same Let's Encrypt equal cert.crt|cert.pem and fullchain.pem.
    """
    sources_to_remove = []
    for cert_source in summary.sources:
        if not isinstance(cert_source, CertificateSource):
            continue

        similar_paths = [ cert_source.path ]
        dir_name = os.path.dirname(cert_source.path)
        if 'letsencrypt' in dir_name:
            if cert_source.path.endswith('cert.pem') or cert_source.path.endswith('cert.crt'):
                similar_paths.append(dir_name + '/fullchain.pem')
            elif cert_source.path.endswith('fullchain.pem'):
                similar_paths += [ dir_name + '/cert.pem', dir_name + '/cert.crt' ]

        cert_already_in_web_source = False
        for web_source in summary.sources:
            if not isinstance(web_source, WebSource):
                continue
            for path in similar_paths:
                if path in web_source.certificates:
                    cert_already_in_web_source = True
        if cert_already_in_web_source:
            sources_to_remove.append(cert_source)

    for source_to_remove in sources_to_remove:
        if source_to_remove in summary.sources:
            summary.sources.remove(source_to_remove)

def list_apache_domains(vhosts: List[ApacheVhost]):
    """ Parse Apache vhosts in search of domains.
    Return a list of WebSource.
    """
    print_debug('Listing Apache domains.')
    apache_conf = load_apache_conf(vhosts)

    sources = []
    for vhost in vhosts:
        domains = list(set(vhost.aliases + [vhost.servername]))  # list(set(list)) removes duplicates
        # Remove 'default' domain
        domains = list(set(domains) - {'default'})  # substraction can only be done on sets, not lists

        for domain in domains:
            # Search if there is a WebSource for this domain/path pair
            source = None
            for s in sources:
                if s.domain == domain and s.path == vhost.path:
                    source = s
                    break
            # Else, create a new WebSource
            if not source:
                # Remove current domain (self)
                roommates = list(set(domains) - {domain})  # substraction can only be done on sets, not lists
                source = WebSource(domain, roommates, 'apache', vhost.path)
                sources.append(source)

            source.add_port(vhost.port)

            # Agregate other infos from vhost conf lines
            for file_path, file_conf in apache_conf[vhost.path].items(): # apache_conf[vhost.path] contains a dict of { file_path: { nline, line } }
                for nline, line in file_conf.items():
                    # Pass lines before <VirtualHost> start only in vhost config file (not in included files)
                    if file_path == vhost.path and nline < vhost.start_line:
                        continue
                    words = line.split()
                    if ('ServerName' in words or 'ServerAlias' in words) and domain in words:
                        source.add_line_number(nline)
                    elif words[0] in ['SSLCertificateFile', 'SSLCertificateChainFile']:
                        cert_path = words[1]
                        if cert_path[0] != '/':  # path relative to ServerRoot (which is assumed to be /etc/apache2)
                            cert_path = '/etc/apache2/' + cert_path
                        if words[0] == 'SSLCertificateFile':
                            source.add_certificate(cert_path)
                        elif words[0] == 'SSLCertificateChainFile':
                            source.add_intermediate_certificate(cert_path)
                    elif '</VirtualHost>' in line:
                        break

    return sources


def parse_apache_dump_vhosts():
    """ Parse Apache DUMP_VHOSTS in search of domains.
    Return a dict of { domain: ApacheVhost object }
    """
    print_debug('Parsing output of apache2ctl -t -D DUMP_VHOSTS.')
    try:
        stdout, stderr, rc = execute('apache2ctl -t -D DUMP_VHOSTS')
    except:
        print_debug('Apache is not present, passing.')
        return {}

    vhosts = []
    cur_vhost = None
    for line in stdout:
        words = line.strip().split()
        if 'namevhost' in words and len(words) >= 5:
            # Save previous vhost
            if cur_vhost:
                vhosts.append(cur_vhost)
            # Parse vhost line
            # format: port PORT namevhost DOMAIN (VHOST_PATH:VHOST_LINE_NUMBER)
            port = int(words[1])
            domain = words[3].strip()
            path, nline = words[4].strip('()').split(':')
            cur_vhost = ApacheVhost(domain, path, int(port), int(nline))

        elif 'wild alias ' in line:
            # Parse wild alias line
            # format: wild alias DOMAIN
            cur_vhost.aliases.append(words[2].strip())

        elif 'alias' in words and len(words) >= 2:
            # Parse alias line
            # format: alias DOMAIN
            cur_vhost.aliases.append(words[1].strip())

    return vhosts


def load_apache_conf(vhosts: List[ApacheVhost]):
    """ If available, parse Apache DUMP_CONFIG, else parse vhost files.
    vhosts: list of ApacheVhost objects
    Parse each vhost conf path, which can contain includes.
    Return conf lines by file in a dict:
        { conf_path: dict { included_file_path: dict { num_line: line } }
    Example: {
        "/etc/apache2/sites-enabled/default": {
            "/etc/apache2/sites-enabled/000-default": {
                "1": "<VirtualHost *:80>"
                "2": "ServerName default"
                "3": "Include /etc/apache2/ssl/000-default"
                …
            },
            "/etc/apache2/ssl/000-default": {
                "1": "SSLEngine on"
                "2": "SSLCertificateFile /etc/ssl/certs/evoadmin.test-www00.evolix.eu.crt"
                …
            },
        },
        "/etc/apache2/sites-enabled/mysite": {
        …
    }
    """
    conf_paths = list(set(map(operator.attrgetter('path'), vhosts))) # list(set(list)) removes duplicates
    apache_conf = {}
    if is_apache_mod_info:
        # Use mod_info instead of reading the conf file
        apache_conf = parse_apache_mod_info(conf_paths)
    else:
        # mod_info is not enabled, read the conf files
        for conf_path in conf_paths:
            apache_conf[conf_path] = load_apache_conf_file(conf_path)
    return apache_conf


def parse_apache_mod_info(vhosts_paths: List[str]):
    """ Parse Apache DUMP_CONFIG of mod_info.
    Return conf lines by file in a dict:
        { vhost_path: dict { included_file_path: dict { num_line: line } }
    Example: see the one in load_apache_conf() docstring.
    """
    print_debug('Parsing output of apache2ctl -t -D DUMP_CONFIG.')
    stdout, stderr, rc = execute('apache2ctl -t -D DUMP_CONFIG')

    apache_conf = {}
    cur_vhost, cur_incl_file = None, None
    i, nline = 0, 0
    while i < len(stdout):
        line = stdout[i]
        words = line.split()

        if 'In file:' in line:
            cur_incl_file = None
            if os.path.exists(words[3]):
                if words[3] in vhosts_paths:
                    # File is a vhost
                    cur_vhost = words[3]
                    cur_incl_file = words[3]
                    if cur_vhost not in apache_conf:
                        apache_conf[cur_vhost] = {}
                    if cur_incl_file not in apache_conf[cur_vhost]:
                        apache_conf[cur_vhost][cur_incl_file] = {}

                elif words[3] not in vhosts_paths:
                    # File is not a vhost but can be useful (for example an included file)
                    cur_incl_file = words[3]
                    if cur_vhost and (cur_vhost in vhosts_paths) and (cur_incl_file not in apache_conf[cur_vhost]):
                        apache_conf[cur_vhost][cur_incl_file] = {}
                    i += 1
                    continue

        elif cur_vhost:
            if words[0] == '#' and words[1].rstrip(':').isdigit():  # format: ' #  N:'
                # This line indicates the line number, the next one is the real conf line
                nline = int(words[1].rstrip(':'))
                if i+1 > len(stdout)-1: break # EOF (just in case, but it should never happen)
                nextline = stdout[i+1]
                if cur_vhost in vhosts_paths:
                    apache_conf[cur_vhost][cur_incl_file][nline] = nextline
                i += 1
            else:
                nline += 1  # we don't know line number, so we guess it by incrementing the previous number
                if cur_vhost in vhosts_paths:
                    apache_conf[cur_vhost][cur_incl_file][nline] = line
        i += 1
    return apache_conf


def load_apache_conf_file(path):
    """ Recursively parse Apache configuration.
    Return conf lines by file (for Includes)
    in a dict { file_path: dict { num_line: line }
    Not supported: Include of directories.
    """
    conf_files = { path: {} }
    with open(path, encoding='utf-8') as f:
        nline = 0
        for line in f:
            nline += 1
            line = strip_comments(line).strip()
            if not line: continue
            words = line.split()
            conf_files[path][nline] = line
            if 'Include' in words or 'IncludeOptional' in words:
                included_path_glob = words[1] # globbing can be used in Include directive
                if included_path_glob[0] != '/':  # path relative to ServerRoot (which is assumed to be /etc/apache2)
                    included_path_glob = '/etc/apache2/' + included_path_glob
                included_paths = glob.glob(included_path_glob)
                for included_path in included_paths:
                    if os.path.isdir(included_path):
                        # Include all files in the directory tree recursively
                        iterator = os.walk(included_path)
                        for (base_dir, _, files) in iterator:
                            for f in files:
                                conf_path = base_dir + '/' + f
                                conf_files.update(load_apache_conf_file(conf_path))
                    else:
                        conf_files.update(load_apache_conf_file(included_path))
    return conf_files


def list_nginx_domains():
    """ Parse Nginx dynamic conf in search of domains.
    Return a list of WebSource.
    """
    print_debug('Listing Nginx domains.')
    conf = parse_nginx_T()
    sources = []
    for file_path in conf:
        if not file_path.startswith('/etc/nginx/sites-enabled'):
            continue

        # Parse conf in file_path
        file_conf = flatten_nginx_conf_file(file_path, conf)
        conf_file_domains = {}  # { 'example.com': { 'ports': [], 'line_numbers': [] } }

        # For each server directive, all domains, ports and other relevant infos are completely parsed first, then added to a WebSource.
        # This is because
        server_domains_line_numbers = {}  # { 'example.com': [line_number_1, line_number_2…] }
        server_ports, server_certificates = [], []
        for sub_conf_path, nline, line in file_conf:
            # Parse server {} blocks
            if line.startswith('server') and line.endswith('{'): # format: server {
                line = line.strip(' {')
                if line == 'server':
                    # New vhost, save previous vhost infos in conf_file_domains and reset the variables
                    for domain, line_numbers in server_domains_line_numbers.items():
                        if domain not in conf_file_domains:
                            conf_file_domains[domain] = { 'ports': [], 'line_numbers': [], 'certificates': [] }
                        conf_file_domains[domain]['line_numbers'].extend(line_numbers)
                        conf_file_domains[domain]['ports'].extend(server_ports)
                        conf_file_domains[domain]['certificates'].extend(server_certificates)
                    server_domains_line_numbers = {}
                    server_ports, server_certificates = [], []

            # Parse line and note relevant infos (port, domain…)
            elif line.startswith('listen') or line.startswith('server_name') or line.startswith('ssl_certificate'):
                words = line.strip('; ').split()
                if words[0] == 'listen':
                    server_ports.extend(parse_nginx_server_port(words))
                elif words[0] == 'server_name':
                    domains = parse_nginx_server_names(words)
                    for domain in domains:
                        if domain not in server_domains_line_numbers:
                            server_domains_line_numbers[domain] = []
                        server_domains_line_numbers[domain].append(nline)
                elif words[0] == 'ssl_certificate':
                    # line format: ssl_certificate <FILE>;
                    cert_path = words[1].strip(';')
                    server_certificates.append(cert_path)

        # EOF, save last server {} infos in conf_file_domains
        for domain, line_numbers in server_domains_line_numbers.items():
            if domain not in conf_file_domains:
                conf_file_domains[domain] = { 'ports': [], 'line_numbers': [], 'certificates': [] }
            conf_file_domains[domain]['line_numbers'].extend(line_numbers)
            conf_file_domains[domain]['ports'].extend(server_ports)
            conf_file_domains[domain]['certificates'].extend(server_certificates)

        # Then, create a WebSource for each domain found in conf file
        for domain in conf_file_domains:
            roommates = list(set(conf_file_domains) - { domain }) # list(set(list)) removes duplicates
            source = WebSource(domain, roommates, 'nginx', file_path)
            for port in conf_file_domains[domain]['ports']:
                source.add_port(port)
            for line_number in conf_file_domains[domain]['line_numbers']:
                source.add_line_number(line_number)
            for certificate in conf_file_domains[domain]['certificates']:
                source.add_certificate(certificate)
            if source not in sources:
                sources.append(source)
    return sources


def parse_nginx_T():
    """ Parse configuration files in `nginx -T` output.
    Return conf lines by file in a dict: { file_path: (line_number, line) }
    """
    try:
        stdout, stderr, rc = execute('nginx -T')
    except:
        print_debug('Nginx is not present, passing.')
        return {}

    conf = {}
    line_number = 0
    cur_conf_path = None
    for line in stdout:
        line_number += 1
        if line.startswith('# configuration file '):  # format: # configuration file <PATH>:
            line_number = 0
            words = line.strip(' ;').split()
            cur_conf_path = words[3].strip(' :')
            conf[cur_conf_path] = []
        else:
            line = strip_comments(line).strip()
            if line:
                conf[cur_conf_path].append((line_number, line))
    return conf


def flatten_nginx_conf_file(file_path: str, conf: Dict[str, Tuple[int, str]]):
    """ Parse file_path and included files recursively
    Return a List of tuple (path, line_number, line).
    conf: previously parsed Nginx conf
    """
    lines = []
    for nline, line in conf[file_path]:
        words = line.split()
        if words[0] == 'include':
            include_glob = words[1].strip(';')
            include_paths = glob.glob(include_glob)
            for include_path in include_paths:
                lines.extend(flatten_nginx_conf_file(include_path, conf))
        else:
            lines.append((file_path, nline, line))
    return lines


def parse_nginx_server_port(words: List[str]):
    """ Return a list of ports found in words.
    """
    # line format: [IP:]<PORT> [[IP:]<PORT>...] | <OTHER_DIRECTIVES>
    ports = []
    for ip_port in words[1:]:
        parts = ip_port.split(':')
        for part in parts:
            try:
                port = int(part)
                if part not in ports:
                    ports.append(port)
            except: # Not a port
                continue
    return ports


def parse_nginx_server_names(words: List[str]):
    """ Return a list of server_names found in words.
    """
    # line format: server_name <DOMAIN1> [<DOMAINS2 ...];
    domains = []
    for d in words[1:]:
        domain = d.strip()
        if domain in ['_']:
            continue
        domains.append(domain)
    return domains


def list_vhost_domains(site_enabled_name: str):
    """ If site_enabled_name has a vhost conf file in /etc/(apache2|nginx)/site-enabled/,
    return its domains as a list of DomainSource.
    """
    matching_vhosts = []
    for vhost in parse_apache_dump_vhosts():
        vhost_filename = os.path.splitext(os.path.basename(vhost.path))[0]
        if vhost_filename == site_enabled_name:
            matching_vhosts.append(vhost)

    sources = []
    if matching_vhosts:
        sources = list_apache_domains(matching_vhosts)

    for nginx_source in list_nginx_domains():
        vhost_filename = os.path.splitext(os.path.basename(nginx_source.path))[0]
        if vhost_filename == site_enabled_name:
            sources.append(nginx_source)

    return sources


def list_haproxy_certificates():
    """ Return the list of certificates loaded in HaProxy.
    """
    # Find stats socket path
    if not os.path.isfile(haproxy_conf_path):
        return []
    haproxy_conf = read_conf_file(haproxy_conf_path)
    haproxy_stats_socket = None
    for line in haproxy_conf:
        if 'stats' in line and 'socket' in line:
            words = line.split()
            if len(words) >=3:
                haproxy_stats_socket = words[2]
    if not haproxy_stats_socket:
        return []
    try:
        os.stat(haproxy_stats_socket)  # os.path.isfile() does not work on sockets
    except FileNotFoundError:
        return []

    # Ask HaProxy certs via the socket
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(haproxy_stats_socket)
        s.sendall('show ssl cert\n'.encode('utf-8'))
        response = ''
        while True:
            data = s.recv(4096).decode('utf-8')
            if not data:
                break
            response += data

    certs = [ cert for cert in response.split() if os.path.isfile(cert) ]
    return certs


def list_haproxy_certificates_domains():
    """ Return a list of domain CertificateSource from HaProxy.
    """
    sources = []
    for cert_path in list_haproxy_certificates():
        cert_sources = parse_certificate_domains(cert_path, 'haproxy')
        sources.extend(cert_sources)
    return sources


def list_letsencrypt_domains():
    """ Parse certificates in /etc/letsencrypt in search of domains.
    Return a list of CertificateSource.
    """
    print_debug('Listing Let\'s Encrypt certificates domains.')
    if not shutil.which('certbot'):
        print_debug('Certbot not installed, passing.')
        return []

    if shutil.which('evoacme'):
        return list_certificates_domains('/etc/letsencrypt', 'evoacme', '/etc/letsencrypt/{}/live/cert.crt')
    else:
        return list_certificates_domains('/etc/letsencrypt/live', 'certbot', '/etc/letsencrypt/live/{}/cert.pem')


def list_certificates_domains(base_path: str, source: str, cert_path_template: str = None):
    """ Parse certificates in directory base_path in search of domains (not recursive).
    cert_path_template:
        Certificate path containing a {} substitution for String.format() (optional).
        The variable passed to format() is each file or directory found in base_path.
        Exemple for Certbot / Let's Encrypt:
            base_path='/etc/letsencrypt/live'
            cert_path_template='/etc/letsencrypt/live/{}/cert.pem'
    Return a list of CertificateSource.
    """
    base_path = base_path.rstrip('/')
    if not os.path.exists(base_path):
        print_debug('Directory {} does not exist, passing.'.format(base_path))
        return []

    sources = []
    for item in os.listdir(base_path):
        if cert_path_template:
            cert_path = cert_path_template.format(item)
        else:
            cert_path = os.path.join(base_path, item)
        if os.path.isfile(cert_path):
            if base_path == '/etc/ssl/certs' and os.path.islink(cert_path):
                continue  # if file is a link, it is a CA cert, ignore it
            if cert_path == '/etc/ssl/certs/ca-certificates.crt':
                continue
            cert_sources = parse_certificate_domains(cert_path, source)
            if cert_sources:
                sources.extend(cert_sources)
    return sources


def parse_certificate_domains(cert_path: str, source: str):
    """ List the domains in the certificate (in X509 PEM format).
    Argument source is used for CertificateSource.source.
    Return a list of CertificateSource.
    """
    cert = load_certificate(cert_path)
    if not cert: return []
    all_domains = list(set(cert.common_names + cert.alt_names))  # list(set(list)) removes duplicates

    sources = []
    for domain in all_domains:
        roommates = list(set(all_domains) - {domain})
        src = CertificateSource(domain, roommates, source, cert_path)
        if domain in cert.common_names:
            src.add_cert_attribute('CN')
        if domain in cert.alt_names:
            src.add_cert_attribute('SAN')
        sources.append(src)

    return sources



"""
Business logic : checks (DNS, HTTP challenge, certificates…)
"""


class DigThread(threading.Thread):
    """ Thread object that resolves a domain and its IP's reverse, and stores the result.
    """
    def __init__(self, domain: str):
        threading.Thread.__init__(self, daemon=True)
        self.domain = domain
        self.exception = ''
        self.ips = {}  # dict { ip: reverse }

    def run(self):
        """ Resolve domain in the thread.
        """
        try:
            ips = resolve(self.domain)
            if not ips:
                return  # no need for exception, empty self.ips will result in a specific DNSCheckStatus

            # Get IPs reverses
            for ip in ips:
                if ip not in self.ips:
                    if is_numeric:
                        self.ips[ip] = ''
                    else:
                        reverse = get_reverse_dns(ip)
                        reverse = strip_evolix_suffix(reverse) if reverse else ip
                        self.ips[ip] = reverse

        except Exception as e:
            self.exception = e


def check_domains(domains_summaries: Dict[str, DomainSummary]):
    """ Check resolution of domains and save it in a DNSCheckResult object
    in DomainSummary attribute dns_check_result.
    """
    # Resolve domains in threads
    jobs = []  # list of tuples (domain_summary, job)
    for domain, domain_summary in domains_summaries.items():
        if domain_summary.replacement_domain:
            domain = domain_summary.replacement_domain
        if '*' in domain:
            continue
        if not domain_regex.fullmatch(domain): # non FQDN domain
            continue
        t = DigThread(domain)
        t.start()
        jobs.append((domain_summary, t))

    # Wait for jobs to finish or timeout
    for (domain_summary, job) in jobs:
        job.join(DNS_timeout)

        check_result = DNSCheckResult(domain_summary.domain)
        if job.is_alive():
            check_result.set_status(DNSCheckStatus.DNS_TIMEOUT)
        domain_summary.set_dns_check_result(check_result)

    # Analyze DNS check results
    for (domain_summary, job) in jobs:
        check_result = domain_summary.dns_check_result

        if domain_summary.replacement_domain:
            check_result.add_comment('{} DNS checked on {}'.format(domain_summary.domain, domain_summary.replacement_domain))

        for ip in job.ips:
            check_result.add_ip(ip, ip in allowed_ips, job.ips[ip])

        local_ips = []
        for ip in job.ips:
            ip_object = ipaddress.ip_address(ip)
            if ip_object.is_private:
                local_ips.append(ip)
        if local_ips:
            check_result.add_comment('warning: domain resolves to local IP(s): {}'.format(', '.join(local_ips)))

        # Set check_result status
        if not check_result.status:
            if job.exception:
                check_result.set_status(DNSCheckStatus.ERROR)
                exception_name = job.exception.__class__.__name__
                check_result.add_comment('error: {}: {}'.format(exception_name, str(job.exception)))
                print_debug('Exception occured during DNS resolution of {}: {}: {}'.format(domain_summary.domain, exception_name, str(job.exception)))
            elif not job.ips:
                check_result.set_status(DNSCheckStatus.NO_DNS_RECORD)
            elif check_result.unknown_ips:
                check_result.set_status(DNSCheckStatus.UNKNOWN_IPS)
            else:
                check_result.set_status(DNSCheckStatus.OK)

    for domain, domain_summary in domains_summaries.items():
        # Set OK status if domain is in ignored_domains list
        if domain in ignored_domains:
            domain_summary.dns_check_result.set_status(DNSCheckStatus.OK)
            domain_summary.dns_check_result.add_comment('domain is in ignored domains list')

        # Set UNCHECKED status if wildcard has no replacement_domain
        elif '*' in domain and not domain_summary.replacement_domain:
            check_result = DNSCheckResult(domain)
            check_result.set_status(DNSCheckStatus.UNCHECKED)
            check_result.add_comment('not checked because no replacement domain is configured')
            domain_summary.set_dns_check_result(check_result)

        elif not domain_regex.fullmatch(domain): # non FQDN domain
            check_result = DNSCheckResult(domain)
            check_result.set_status(DNSCheckStatus.UNCHECKED)
            check_result.add_comment('not checked because non FQDN domain')
            domain_summary.set_dns_check_result(check_result)

        # Add a comment if roommates have different DNS records
        if domain_regex.fullmatch(domain_summary.domain): # alert only if domain is a FQDN
            check_result = domain_summary.dns_check_result
            for source in domain_summary.sources:
                if check_result.status == DNSCheckStatus.UNCHECKED:
                    continue
                for roommate in source.roommates:
                    roommate_summary = domains_summaries[roommate]
                    if roommate_summary.dns_check_result != check_result and domain_regex.fullmatch(roommate_summary.domain): # alert only if roommate domain is a FQDN
                        check_result.add_comment('warning: domain(s) in the virtual host have different DNS records')
                        break


class HTTPChallengeThread(threading.Thread):
    """ Thread object that executes an HTTP challenge and store its result.
    """
    def __init__(self, domain: str):
        threading.Thread.__init__(self, daemon=True)
        self.domain = domain
        self.challenge_uuid = str(uuid.uuid4())
        self.challenge_path = os.path.join(http_challenge_dir, self.challenge_uuid)
        self.challenge_token = str(uuid.uuid4())
        self.http_status_code = None
        self.received_text = None
        self.exception = ''

    def run(self):
        """ Run a HTTP challenge on domain, like Let's Encrypt.
        Test the challenge on the IPs provided by the authoritative DNS of the domain.
        """
        # Create challenge file
        with open(self.challenge_path, 'w') as f:
            f.write(self.challenge_token)
        uid = pwd.getpwnam("www-data").pw_uid
        gid = grp.getgrnam("www-data").gr_gid
        os.chown(self.challenge_path, uid, gid)
        os.chmod(self.challenge_path, 0o644)

        # Get domain authoritative DNS
        dns_ips = find_authoritative_dns(self.domain)

        domain_ips = resolve(self.domain, dns_ips)
        if not domain_ips:
            self.exception = Exception('The domain {} has no DNS'.format(self.domain))
            # Clean challenge
            os.remove(self.challenge_path)
            return

        # Request a GET challenge on each IP until success or no IP left
        http_return, exception = None, None
        for ip in domain_ips:
            if is_ipv6(str(ip)):
                ip = '[{}]'.format(str(ip))
            try:
                http_return = get_challenge(ip, self.domain, self.challenge_uuid)
                break
            except Exception as e:
                exception = e
                continue

        if http_return is not None:
            self.http_status_code = http_return.status_code
            self.received_text = http_return.text
        else:
            if exception:
                self.exception = exception

        # Clean challenge
        os.remove(self.challenge_path)


def get_challenge(ip: str, domain: str, challenge_uuid: str, http_scheme: str = 'http', redir_count: int = 0):
    """ Make a recursive GET request on IP to retrieve the challenge.
    Handle HTTPS SNI for requests directed to IPs.
    redir_count is the number of redirections already made.
    """
    if redir_count > requests.models.DEFAULT_REDIRECT_LIMIT:
        raise requests.TooManyRedirects('Exceeded {} redirects'.format(str(requests.models.DEFAULT_REDIRECT_LIMIT)))

    challenge_url = http_scheme + '://' + str(ip) + '/' + http_challenge_uri + '/' + challenge_uuid
    if http_scheme == 'https':
        # Use a custom SSLContext to set the SNI
        # Else, we have a HTTP 421 or a "hostname doesn’t match" error
        # requests_toolbelt.HostHeaderSSLAdapter is simple and was tested, but it didn't fix the issue.
        context = CustomSSLContext(domain)
        context.check_hostname = False
        adapter = requests.adapters.HTTPAdapter()
        adapter.init_poolmanager(10, 10, ssl_context=context)
        s = requests.Session()
        s.mount(http_scheme + '://', adapter)
        http_return = s.get(challenge_url, headers={'Host': domain}, verify=False, allow_redirects=False)
    else:
        http_return = requests.get(challenge_url, headers={'Host': domain}, allow_redirects=False)
    # Requests options explanation:
    # - verify=False: we don't care about the certificate
    # - allow_redirects=False: we handle redirections by hand, because we want to requests directly the IP and not the domain.

    if (http_return.is_redirect or http_return.is_permanent_redirect) and 'Location' in http_return.headers:
        # Recursively request the challenge on the redirected location
        location = http_return.headers['Location']
        url_parts = urlsplit(location)
        http_return = get_challenge(ip, url_parts.hostname, challenge_uuid, url_parts.scheme, redir_count + 1)

    return http_return


class CustomSSLContext(ssl.SSLContext):
    """ SSLContext to setup a request SNI.
    Usefull to make requests to IPs instead of domain names.
    Adapted from https://github.com/requests/toolbelt/issues/159#issuecomment-295566494
    """
    def __new__(cls, domain):
        return super().__new__(cls, ssl_protocol)

    def __init__(self, domain):
        super().__init__()
        self._domain = domain

    def change_server_hostname(self, domain):
        self._domain = domain

    def wrap_socket(self, *args, **kwargs):
        kwargs['server_hostname'] = self._domain
        return super(CustomSSLContext, self).wrap_socket(*args, **kwargs)


def challenge_domains(domains_summaries: Dict[str, DomainSummary]):
    """ Challenge the domains with a HTTP request, like Let's Encrypt.
    Save the result in a ChallengeResult object in DomainSummary attribute challenge_result.
    """
    prev_umask = os.umask(int(0o022))
    os.makedirs(http_challenge_dir, exist_ok=True)
    os.umask(prev_umask)

    # Run challenges on all domains in threads
    jobs = []  # list of tuples (domain_summary, job)
    for domain, domain_summary in domains_summaries.items():
        if domain_summary.replacement_domain:
            domain = domain_summary.replacement_domain
        if '*' in domain:
            continue
        if not domain_regex.fullmatch(domain): # non FQDN domain
            continue
        t = HTTPChallengeThread(domain)
        t.start()
        jobs.append((domain_summary, t))

    # Wait for jobs to finish or timeout
    for (domain_summary, job) in jobs:
        job.join(http_challenge_timeout)

        challenge_result = HTTPChallengeResult(domain_summary.domain)
        if job.is_alive():
            challenge_result.set_status(HTTPChallengeStatus.REQUEST_TIMEOUT)
        domain_summary.set_http_challenge_result(challenge_result)

    # Analyze HTTP challenge results
    for (domain_summary, job) in jobs:
        challenge_result = domain_summary.http_challenge_result

        if domain_summary.replacement_domain:
            challenge_result.add_comment('{} HTTP challenge made on {}'.format(domain_summary.domain, domain_summary.replacement_domain))

        challenge_result.http_status_code = job.http_status_code

        # Set challenge_result status
        if not challenge_result.status:
            if job.received_text == job.challenge_token:
                challenge_result.set_status(HTTPChallengeStatus.SUCCESS)
            elif challenge_result.http_status_code and challenge_result.http_status_code != 200:
                challenge_result.set_status(HTTPChallengeStatus.UNEXPECTED_HTTP_STATUS)
            elif job.exception:
                challenge_result.set_status(HTTPChallengeStatus.ERROR)
                if isinstance(job.exception, requests.ConnectionError):
                    challenge_result.add_comment('error: could not establish connection to {}'.format(domain_summary.domain))
                else:
                    exception_name = job.exception.__class__.__name__
                    if exception_name != 'Exception':
                        challenge_result.add_comment('error: {}: {}'.format(exception_name, str(job.exception)))
                    else:
                        challenge_result.add_comment('error: {}'.format(str(job.exception)))
                    print_debug('Exception occured during HTTP challenge request of {}: {}: {}'.format(domain_summary.domain, exception_name, str(job.exception)))
            else:
                challenge_result.set_status(HTTPChallengeStatus.ERROR)
                challenge_result.add_comment('error: unknown type of error')
                print_debug('Unknown type of error occured during HTTP challenge request of {}'.format(domain_summary.domain))

    for domain, domain_summary in domains_summaries.items():
        challenge_result = domain_summary.http_challenge_result
        check_dns_result = domain_summary.dns_check_result

        # Set IGNORED status if domain is in ignored_domains list
        if domain in ignored_domains:
            challenge_result.set_status(HTTPChallengeStatus.IGNORED)
            challenge_result.add_comment('domain is in ignored domains list')

        # Set UNCHECKED status if wildcard has no replacement_domain
        elif '*' in domain and not domain_summary.replacement_domain:
            challenge_result.set_status(HTTPChallengeStatus.UNCHECKED)
            challenge_result.add_comment('not checked because no replacement domain is configured')

        # Set UNCHECKED status if non FQDN domain
        elif not domain_regex.fullmatch(domain):
            challenge_result.set_status(HTTPChallengeStatus.UNCHECKED)
            challenge_result.add_comment('not checked because non FQDN domain')

        if challenge_result.status not in [HTTPChallengeStatus.SUCCESS, HTTPChallengeStatus.UNCHECKED]:
            if len(check_dns_result.unknown_ips) > 0: # don't use DNSCheckStatus.UNKNOWN_IPS as it can be replaced by HTTPChallengeStatus.IGNORED/UNCHECKED (yes this is bad)
                challenge_result.add_comment('domain points to unknown IPs')
            if check_dns_result.status == DNSCheckStatus.DNS_TIMEOUT:
                challenge_result.add_comment('timeout occurs when quering DNS')
            elif check_dns_result.status == DNSCheckStatus.NO_DNS_RECORD:
                challenge_result.add_comment('domain has no DNS record')
            elif check_dns_result.status == DNSCheckStatus.ERROR:
                challenge_result.add_comment('an error occurs when checking DNS')


def check_certificates(domains_summaries: Dict[str, DomainSummary]):
    """ Check certificates contained in domains_summaries.
    Return a list of Certificate objects with cert_check_result attribute
    containing a CertCheckResult object.
    """
    certs = {}
    for domain, domain_summary in domains_summaries.items():
        if is_check_valid_domains:
            if domain_summary.dns_check_result.status != DNSCheckStatus.OK:
                continue
        for source in domain_summary.sources:
            if isinstance(source, CertificateSource):
                if source.path not in certs:
                    cert = check_certificate(source.path)
                    if cert:
                        certs[source.path] = cert

            if isinstance(source, WebSource):
                for cert_path in source.certificates:
                    if cert_path not in certs:
                        cert = check_certificate(cert_path, source)
                        if cert:
                            certs[cert_path] = cert

    return list(certs.values())


def check_certificate(cert_path: str, vhost_source: WebSource = None):
    """ Check certificate.
    If argument vhost_source is provided, check that vhost domains are covered by the certificate.
    Return a Certificate object with a CertCheckResult object set in attribute cert_check_result.
    """
    cert = load_certificate(cert_path)
    if not cert: return None

    # Check expiration status
    warn_time = datetime.now(timezone.utc) + exp_days_warn
    crit_time = datetime.now(timezone.utc) + exp_days_crit
    if cert.end_date < datetime.now(timezone.utc):
        check_result = CertCheckResult(CertExpirationStatus.EXPIRED)
    elif cert.end_date < crit_time:
        check_result = CertCheckResult(CertExpirationStatus.EXPIRES_VERY_SOON)
        expiration_delta = cert.end_date - datetime.now(timezone.utc).replace(microsecond=0)
        check_result.add_comment('will expire in {}'.format(expiration_delta))
    elif cert.end_date < warn_time:
        check_result = CertCheckResult(CertExpirationStatus.EXPIRES_SOON)
        expiration_delta = cert.end_date - datetime.now(timezone.utc).replace(microsecond=0)
        check_result.add_comment('will expire in {}'.format(expiration_delta))
    else:
        check_result = CertCheckResult(CertExpirationStatus.OK)

    # Check if certificate is self-signed
    check_result.is_self_signed = cert.issuer in cert.common_names

    # Set OK status if cert in ignored_certs list
    if cert_path in ignored_certs:
        check_result = CertCheckResult(CertExpirationStatus.OK)
        check_result.add_comment('certificate is in ignored certs list')

    # Check that vhost domains are covered by certificate
    if vhost_source and isinstance(vhost_source, WebSource):
        cert.vhost_path = vhost_source.path

        cert_domains, cert_wildcards = [], []
        for domain in cert.common_names + cert.alt_names:
            if domain[0:2] == '*.':  # *.example.com
                cert_wildcards.append(domain[2:])  # without the *. part: example.com
            else:
                cert_domains.append(domain)

        vhost_domains = [ vhost_source.domain ] + vhost_source.roommates
        for domain in vhost_domains:
            if domain not in cert_domains:
                if domain in ignored_domains:
                    continue
                if not domain_regex.fullmatch(domain): # do not alert if domain is not FQDN
                    continue
                domain_level_up = '.'.join(domain.split('.')[1:])
                if domain_level_up not in cert_wildcards:
                    check_result.add_not_covered_domain(domain)

    # [WIP] Check validity and chain
    # Someday: Check also private key
    #if cryptography_handles_verification: # cryptography module version >= 42 (>= Deian 13 Trixie))
    #    # Load certs to verify (including intermediates)
    #    with open(cert_path, 'rb') as cert_file:
    #       certs = x509.load_pem_x509_certificates(cert_file.read())  # crypto version >= 39 (>= Deian 13 Trixie))
    #    x509_cert = certs[0]
    #    intermediates = certs[1:] if len(certs) > 1 else None
    #
    #    verifier_builder = x509.verification.PolicyBuilder()
    #
    #    # Load root certs
    #    with open('/etc/ssl/certs/ca-certificates.crt', 'rb') as ca_bundle:
    #       store = x509.verification.Store(x509.load_pem_x509_certificates(ca_bundle.read()))
    #    verifier_builder = verifier_builder.store(store)
    #
    #    verifier_builder = verifier_builder.time(verification_time)
    #
    #    domain_name = x509.DNSName(x509_cert.common_names[0])
    #    verifier = verifier_builder.build_server_verifier(domain_name)
    #    chain = verifier.verify(x509_cert, intermediates)
    #    # TODO: add to check result

    cert.set_cert_check_result(check_result)
    return cert


def load_certificate(cert_path: str):
    """ Parse certificate and return an instance of Certificate.
    """
    cn_domains = []
    san_domains = []
    end_date = None

    with open(cert_path, 'rb') as f:
        try:
            cert = x509.load_pem_x509_certificate(f.read(), default_backend())
        except:  # This is not a X509 certificate
            return None

        # Issuer
        issue = None
        issuer_org_name = cert.issuer.get_attributes_for_oid(x509.oid.NameOID.ORGANIZATION_NAME)
        if issuer_org_name:
            issuer = issuer_org_name[0].value
        else:
            issuer_cn = cert.issuer.get_attributes_for_oid(x509.oid.NameOID.COMMON_NAME)
            if issuer_cn:
                issuer = issuer_cn[0].value

        # Common name (format: subject: [...], CN=<COMMON NAME>, [...])
        cert_cns = cert.subject.get_attributes_for_oid(x509.oid.NameOID.COMMON_NAME)
        for cert_cn in cert_cns:
            dom = cert_cn.value
            match = domain_regex.search(dom)
            if match and match.group(1):
                cn_domains.append(match.group(1))
        if not cn_domains:
            return  # No CN containing a domain, ignore this certificate file

        # Subject Alternative Name (format: DNS:<DOMAIN1>, DNS:<DOMAIN2>[, ...])
        try:
            san_ext = cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
            cert_sans = san_ext.value.get_values_for_type(x509.DNSName)
            for cert_san in cert_sans:
                match = domain_regex.search(cert_san)
                if match and match.group(1):
                    if match.group(1) not in cn_domains: # avoid duplicates between CNs and SANs
                        san_domains.append(match.group(1))
                else:
                    print_warning('Could not decode SAN {} in {}'.format(cert_san, cert_path))
        except x509.ExtensionNotFound:
            pass
        except Exception:
            print_warning('Unkown error during SAN parsing in {}'.format(cert_path))

        # End date
        end_date = cert.not_valid_after_utc if cryptography_major_version >= 42 else cert.not_valid_after

    # Make end_date timezone-aware, to allow later comparisons with other datetimes
    if is_naive_datetime(end_date):
        end_date = end_date.replace(tzinfo=timezone.utc)

    return Certificate(cert_path, cn_domains, san_domains, end_date, issuer)



"""
CLI : Print functions and classes
"""


class Color:
    """Color strings with shell color codes.
    Methods are static, which involves that they must be called on the class, not on an instance of the class.
    """

    def green(string: str):
        if is_interactive or is_color:
            string = '\033[0;38;5;2m' + string + '\033[0m'
        return string

    def bold_yellow(string: str):
        if is_interactive or is_color:
            string = '\033[1;38;5;3m' + string + '\033[0m'
        return string

    def bold_orange(string: str):
        if is_interactive or is_color:
            string = '\033[1;38;5;208m' + string + '\033[0m'
        return string

    def build_colored_string(strings: List[str], color, separator: str = ','):
        """ Return a colored string joined with separator.
        When printing a colored string containing \n, tabulate has a bug that
        shifts left the next column item. Coloring each string and joining them
        later with join() is a workaround.
        Note: the separator is not colored.
        """
        colored_strings = map(color, strings)
        return separator.join(colored_strings)


def print_error_and_exit(s: str):
    if output == 'nrpe':
        print('UNKNOWN - {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(3)
    else:
        print('Error: {}'.format(s), file=sys.stderr, flush=True)
        sys.exit(1)


def print_warning(s: str):
    if is_warning and output != 'nrpe':  # not NRPE because is_warning is true by default
        print('Warning: {}'.format(s), file=sys.stderr, flush=True)


def print_debug(s: str):
    if is_debug:
        print('Debug: {}'.format(s), flush=True)

def print_pager(output: str):
    """ Print output to pager.
    Less exits if the content fits into the current screen.
    This is why print() must also be called, in addition to this function.
    """
    if is_pager and is_interactive:
        tmp_stdout = tempfile.NamedTemporaryFile('w')
        print(output, file=tmp_stdout, flush=True)

        pager_cmd = '{} {}'.format(pager, tmp_stdout.name)
        subprocess.run(pager_cmd.split(), stdin=subprocess.PIPE)

    else:
        try:
            print(output)
        except BrokenPipeError:
            # Occurs when "evodomains … | head" (or tail)
            pass


def print_allowed_ips():
    """ Print IPs allowed in configuration file allowed_ips.
    """
    if output != 'json':
        print('Allowed IPs (from server IPs and evodomains configuration):')
    if not is_numeric:
        allowed_ip_reverses = query_ip_reverses(allowed_ips)
        stdout, stderr, rc = execute('hostname -I')
        if stdout:
            host_ips = stdout[0].strip().split()
            allowed_ips.extend(host_ips)
            for ip in host_ips:
                allowed_ip_reverses[ip] = 'localhost'
        if output == 'json':
            print(json.dumps({'allowed_ips': allowed_ip_reverses}, sort_keys=True, indent=4))
        else:
            for ip in allowed_ip_reverses:
                print('  - {} ({})'.format(ip, allowed_ip_reverses[ip]))
    else:
        if output == 'json':
            print(json.dumps({'allowed_ips': allowed_ip_reverses}, sort_keys=True, indent=4))
        else:
            for ip in allowed_ips:
                print('  - {}'.format(ip))


def print_domains(domains_summaries: Dict[str, DomainSummary], output_format: str = 'table'):
    """ Print domains_summaries dict to stdout.
    """
    # Filter out invalid domains
    if is_check_valid_domains:
        # list(domains_summaries.items()) makes a copy, which is needed because we will delete an item from the dict we are iterating over
        for domain, domain_summary in list(domains_summaries.items()):
            if domain_summary.dns_check_result.status != DNSCheckStatus.OK:
                del domains_summaries[domain]

    if output_format == 'json':
        print(json.dumps(domains_summaries, sort_keys=True, indent=4, cls=CustomJSONEncoder))
        return

    header = ['Domain', 'Source', 'Path', 'Line number(s)', 'Certificate(s)']
    data = []
    for domain in sorted_domains(domains_summaries):
        for source in domains_summaries[domain].sources:
            if isinstance(source, WebSource):
                data.append([domain, source.source, source.path, ','.join(to_str(source.line_numbers)), ' '.join(source.certificates)])
            elif isinstance(source, ExtraDomainConfFileSource):
                data.append([domain, source.source + '_conf', source.path, ','.join(to_str(source.line_numbers)), ''])
            elif isinstance(source, EvodomainCommandLineSource):
                pass  # domain as a CLI argument is permitted only with check-dns
            elif isinstance(source, CertificateSource):
                data.append([domain, source.source, '', '', source.path])
            else:
                data.append([domain, 'unknown'])

    if is_header:
        output_str = tabulate(data, headers=header) # 'colalign' parameter (idealy right for domain name) only available from Debian 11 (tabulate 0.8.7)
    else:
        output_str = tabulate(data, tablefmt='plain')
    print_pager(output_str)


def print_dns_check(domains_summaries: Dict[str, DomainSummary], output_format: str = 'table'):
    """ Print DNS check results contained in domains_summaries dict to stdout.
    """
    if output_format == 'json':
        check_results = []
        for domain in domains_summaries:
            check_results.append(domains_summaries[domain].dns_check_result)
        print(json.dumps(check_results, indent=4, cls=CustomJSONEncoder))
        return

    sorted_domains = sorted_domains_by_dns_check_result(domains_summaries)

    if output_format == 'table':
        header = ['Domain', 'Check result', 'Allowed hosts', 'Unknown hosts', 'Vhost', 'Comments']
        data = []
        for domain in sorted_domains:
            check_result = domains_summaries[domain].dns_check_result

            allowed_ips = check_result.allowed_ips if is_numeric else check_result.allowed_ips_reverses
            unknown_ips = check_result.unknown_ips if is_numeric else check_result.unknown_ips_reverses
            sep = ', ' if is_numeric else '\n'  # use line return between reverses because they can be very long
            vhosts_paths = []
            for source in domains_summaries[domain].sources:
                if isinstance(source, WebSource) and source.path not in vhosts_paths:
                    vhosts_paths.append(source.path)

            # Add colors
            allowed_ips_str = Color.build_colored_string(allowed_ips, Color.green, sep)
            unknown_ips_str = Color.build_colored_string(unknown_ips, Color.bold_yellow, sep)
            if check_result.status == DNSCheckStatus.OK:
                domain_str = Color.green(domain)
                check_result_str = Color.green(check_result.status.name)
                vhosts_paths_str = Color.build_colored_string(vhosts_paths, Color.green, '\n')
            else:
                domain_str = Color.bold_yellow(domain)
                check_result_str = Color.bold_yellow(check_result.status.name)
                vhosts_paths_str = Color.build_colored_string(vhosts_paths, Color.bold_yellow, '\n')
            comments_color = Color.green if check_result.status == DNSCheckStatus.OK else Color.bold_yellow
            for comment in check_result.comments:
                if 'warning' in comment.lower():
                    comments_color = Color.bold_yellow
            comments_str = Color.build_colored_string(check_result.comments, comments_color, '\n')

            data.append([domain_str, check_result_str, allowed_ips_str, unknown_ips_str, vhosts_paths_str, comments_str])

        if is_header:
            output_str = tabulate(data, headers=header) # colalign parameter (idealy right for domain name) only available from Debian 11 (tabulate 0.8.7)
        else:
            output_str = tabulate(data, tablefmt='plain')
        print_pager(output_str)


    elif output_format == 'nrpe':

        # Count check results
        n_ok, n_warnings, n_errors = 0, 0, 0
        for domain in sorted_domains:
            check_result = domains_summaries[domain].dns_check_result
            if check_result.status == DNSCheckStatus.OK:
                n_ok += 1
            if check_result.status in [DNSCheckStatus.DNS_TIMEOUT, DNSCheckStatus.NO_DNS_RECORD, DNSCheckStatus.UNKNOWN_IPS]:
                n_warnings += 1
            if check_result.status == DNSCheckStatus.ERROR:
                n_errors += 1

        status = 'WARNING' if n_warnings or n_errors else 'OK'
        print('{} - {} UNK / 0 CRIT / {} WARN / {} OK \n'.format(status, n_errors, n_warnings, n_ok))

        for domain in sorted_domains:
            check_result = domains_summaries[domain].dns_check_result
            if check_result.status == DNSCheckStatus.OK:
                continue # domains with DNSCheckStatus.OK will be printed later if is_verbose

            comments = ''
            if is_verbose and check_result.comments:
                comments = ' (' + ', '.join(check_result.comments).lower() + ')'

            vhosts_paths = []
            for source in domains_summaries[domain].sources:
                if isinstance(source, WebSource) and source.path not in vhosts_paths:
                    vhosts_paths.append(source.path)
            vhosts_paths_str = ' ({})'.format(', '.join(vhosts_paths)) if vhosts_paths else ''

            if check_result.status == DNSCheckStatus.ERROR:
                print('UNKNOWN - DNS status of {}{}{}'.format(domain, comments, vhosts_paths_str))
            elif check_result.status == DNSCheckStatus.DNS_TIMEOUT:
                print('WARNING - timeout resolving {}{}{}'.format(domain, comments, vhosts_paths_str))
            elif check_result.status == DNSCheckStatus.NO_DNS_RECORD:
                print('WARNING - no DNS record for {}{}{}'.format(domain, comments, vhosts_paths_str))
            elif check_result.status == DNSCheckStatus.UNKNOWN_IPS:
                allowed_ips = check_result.allowed_ips if is_numeric else check_result.allowed_ips_reverses
                unknown_ips = check_result.unknown_ips if is_numeric else check_result.unknown_ips_reverses
                if allowed_ips:
                    print('WARNING - {} resolves to unknown IP(s): {} and allowed IPs: {}{}{}'.format(domain, ', '.join(unknown_ips), ', '.join(allowed_ips), comments, vhosts_paths_str))
                else:
                    print('WARNING - {} resolves to unknown IP(s): {}{}{}'.format(domain, ', '.join(unknown_ips), comments, vhosts_paths_str))

        if is_verbose:
            for domain in sorted_domains:
                check_result = domains_summaries[domain].dns_check_result
                if check_result.status == DNSCheckStatus.OK:
                    vhosts_paths = []
                    for source in domains_summaries[domain].sources:
                        if isinstance(source, WebSource) and source.path not in vhosts_paths:
                            vhosts_paths.append(source.path)
                    vhosts_paths_str = ' ({})'.format(', '.join(vhosts_paths)) if vhosts_paths else ''

                    comments = ''
                    if check_result.comments:
                        comments = ' (' + ', '.join(check_result.comments).lower() + ')'

                    allowed_ips = check_result.allowed_ips if is_numeric else check_result.allowed_ips_reverses
                    unknown_ips = check_result.unknown_ips if is_numeric else check_result.unknown_ips_reverses
                    if unknown_ips and allowed_ips:
                        print('OK - {} resolves to unknown IP(s): {} and allowed IPs: {}{}{}'.format(domain, ', '.join(unknown_ips), ', '.join(allowed_ips), comments, vhosts_paths_str))
                    elif allowed_ips:
                        print('OK - {} resolves to allowed IP(s): {}{}{}'.format(domain, ', '.join(allowed_ips), comments, vhosts_paths_str))
                    else:
                        print('OK - {}{}{}'.format(domain, comments, vhosts_paths_str))

        sys.exit(1) if n_warnings or n_errors else sys.exit(0)


def print_challenge_results(domains_summaries: Dict[str, DomainSummary], output_format: str = 'table'):
    """ Print HTTP challenge results contained in domains_summaries dict to stdout.
    """
    if output_format == 'json':
        http_challenge_results = []
        for domain in domains_summaries:
            http_challenge_results.append(domains_summaries[domain].http_challenge_result)
        print(json.dumps(http_challenge_results, indent=4, cls=CustomJSONEncoder))
        return

    sorted_domains = sorted_domains_by_http_challenge_result(domains_summaries)

    if output_format == 'table':
        header = ['Domain', 'Challenge result', 'HTTP status', 'Comments']
        data = []
        for domain in sorted_domains:
            challenge_result = domains_summaries[domain].http_challenge_result

            # Add colors
            if challenge_result.status in [HTTPChallengeStatus.SUCCESS, HTTPChallengeStatus.IGNORED]:
                color = Color.green
            elif challenge_result.status in [HTTPChallengeStatus.UNCHECKED]:
                color = Color.bold_yellow
            else:
                color = Color.bold_orange
            domain_str = color(domain)
            challenge_result_str = color(challenge_result.status.name)
            http_status_str = color(str(challenge_result.http_status_code))
            comments_str = Color.build_colored_string(challenge_result.comments, color, '\n')

            data.append([domain_str, challenge_result_str, http_status_str, comments_str])

        if is_header:
            output_str = tabulate(data, headers=header) # colalign parameter (idealy right for domain name) only available from Debian 11 (tabulate 0.8.7)
        else:
            output_str = tabulate(data, tablefmt='plain')

        print_pager(output_str)


def print_certificates_check(certificates: List[Certificate], output_format: str = 'table'):
    """ Print certificates check results to stdout.
    """
    if output_format == 'json':
        certificates = sorted_certificates_by_path(certificates)
        print(json.dumps(certificates, indent=4, cls=CustomJSONEncoder))

    # Sort certificates
    expired, missing_domains, expires_very_soon, expires_soon, ok = [], [], [], [], []
    for cert in certificates:
        if cert.path in ignored_certs:
            ok.append(cert)
            continue
        status = cert.cert_check_result.expiration_status
        if status == CertExpirationStatus.EXPIRED:
            expired.append(cert)
        elif status == CertExpirationStatus.EXPIRES_VERY_SOON:
            expires_very_soon.append(cert)
        elif status == CertExpirationStatus.EXPIRES_SOON:
            expires_soon.append(cert)
        elif cert.cert_check_result.not_covered_domains:
            missing_domains.append(cert)
        else:
            ok.append(cert)
    sorted_certificates = (sorted_certificates_by_path(expired)
            + sorted_certificates_by_path(expires_very_soon) + sorted_certificates_by_path(expires_soon)
            + sorted_certificates_by_path(missing_domains) + sorted_certificates_by_path(ok))

    if output_format == 'table':
        header = ['Path', 'Status', 'End date', 'Vhost', 'Common names', 'Alternate names',  'Missing domains', 'Comments']
        data = []
        for cert in sorted_certificates:
            status = cert.cert_check_result.expiration_status

            colors = { 'path': Color.green, 'status': Color.green, 'enddate': Color.green, 'domains': Color.green }
            if cert.path not in ignored_certs:
                if cert.cert_check_result.not_covered_domains: # MISSING_DOMAINS
                    colors['status'], colors['path'] = Color.bold_yellow, Color.bold_yellow
                if status == CertExpirationStatus.EXPIRED:
                    for i in colors: colors[i] = Color.bold_orange
                elif status == CertExpirationStatus.EXPIRES_VERY_SOON:
                    for i in colors: colors[i] = Color.bold_orange
                elif status == CertExpirationStatus.EXPIRES_SOON:
                    for i in colors: colors[i] = Color.bold_yellow

            # Add colors
            path_str = colors['path'](cert.path)
            status_str = colors['status'](status.name)
            if cert.cert_check_result.not_covered_domains and cert.path not in ignored_certs:
                if status == CertExpirationStatus.OK:
                    status_str = colors['status']('MISSING_DOMAINS')
                else:
                    status_str += colors['status'](' + MISSING_DOMAINS')
            if cert.cert_check_result.is_self_signed:
                if status == CertExpirationStatus.OK:
                    status_str = Color.bold_yellow('SELF_SIGNED')
                else:
                    status_str += Color.bold_yellow(' + SELF_SIGNED')
            end_date_str = colors['enddate'](cert.end_date.strftime('%Y-%m-%d %H:%M'))
            vhost_str = colors['status'](cert.vhost_path) if cert.vhost_path else ''
            common_names = Color.build_colored_string(cert.common_names, colors['domains'], ',')
            alt_names = Color.build_colored_string(cert.alt_names, colors['domains'], '\n')
            missing_domains_str = Color.build_colored_string(cert.cert_check_result.not_covered_domains, colors['status'], '\n')
            comments_str = Color.build_colored_string(cert.cert_check_result.comments, colors['status'], '\n')

            data.append([path_str, status_str, end_date_str, vhost_str, common_names, alt_names, missing_domains_str, comments_str])

        if is_header:
            output_str = tabulate(data, headers=header)
        else:
            output_str = tabulate(data, tablefmt='plain')
        print_pager(output_str)

    elif output_format == 'nrpe':
        if expired or expires_very_soon:
            status = 'CRITICAL'
        elif expires_soon or missing_domains:
            status = 'WARNING'
        else:
            status = 'OK'
        print('{} - {} CRIT / {} WARN / {} OK\n'.format(status, len(expired) + len(expires_very_soon), len(expires_soon) + len(missing_domains), len(ok)))

        for cert in sorted_certificates:
            expiration_delta = cert.end_date - datetime.now(timezone.utc).replace(microsecond=0)
            if expiration_delta <= exp_days_warn or expiration_delta <= exp_days_crit:
                expiration_delta_str = str(expiration_delta)
            else:
                expiration_delta_str = '{} days'.format(expiration_delta.days)
            end_date_str = cert.end_date.strftime('%Y-%m-%d at %H:%M')
            vhost_str = ' Vhost: {}'.format(cert.vhost_path) if cert.vhost_path else ' Not found in a vhost but could be used elsewhere.'

            status = cert.cert_check_result.expiration_status
            if cert.path in ignored_certs:
                if is_verbose:
                    comments = ''
                    if cert.cert_check_result.comments:
                        comments = ' Comments: ' + ', '.join(cert.cert_check_result.comments).lower()
                    print('OK - {} ({}) will expire in {} ({}).{}'.format(cert.path, cert.common_names[0], expiration_delta_str, end_date_str, comments))
                continue
            if status == CertExpirationStatus.EXPIRED:
                print('CRITICAL - {} ({}) is expired since {}!{}'.format(cert.path, cert.common_names[0], end_date_str, vhost_str))
            elif status == CertExpirationStatus.EXPIRES_VERY_SOON:
                print('CRITICAL - {} ({}) will expire in {} ({}).{}'.format(cert.path, cert.common_names[0], expiration_delta_str, end_date_str, vhost_str))
            elif status == CertExpirationStatus.EXPIRES_SOON:
                print('WARNING - {} ({}) will expire in {} ({}).{}'.format(cert.path, cert.common_names[0], expiration_delta_str, end_date_str, vhost_str))

            if cert.cert_check_result.not_covered_domains:
                missing_domains_str = ','.join(cert.cert_check_result.not_covered_domains)
                print('WARNING - {} ({}) does not cover domains in vhost {}: {}'.format(cert.path, cert.common_names[0], cert.vhost_path, missing_domains_str))
            if is_verbose and cert.cert_check_result.expiration_status == CertExpirationStatus.OK and not cert.cert_check_result.not_covered_domains:
                print('OK - {} ({}) will expire in {} ({}).{}'.format(cert.path, cert.common_names[0], expiration_delta_str, end_date_str, vhost_str))

        if expired or expires_very_soon:
            sys.exit(2)
        elif expires_soon or missing_domains:
            sys.exit(1)
        else:
            sys.exit(0)



"""
Utilitary functions
"""


def execute(cmd: str, timeout: int = None, shell: bool = False):
    """ Execute shell command.
    - cmd: the command to execute
    - timeout: in seconds
    - shell: if True, pass directly the command to shell (useful for pipes).
    Before use shell=True, consider security warning:
      https://docs.python.org/3/library/kess.html#security-considerations

    Return stdout and stderr as arrays of UTF-8 strings, and the return code.
    """
    if not shell:
        cmd = cmd.split()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=shell)
    stdout, stderr = proc.communicate(timeout=timeout)

    stdout_lines = stdout.decode('utf-8').splitlines()
    stderr_lines = stderr.decode('utf-8').splitlines()

    return stdout_lines, stderr_lines, proc.returncode


def strip_evolix_suffix(domain: str):
    """ If domain ends with '.evolix.net' or '.rev.as197696.net', remove it.
    """
    strip_domain_ends = ['.evolix.net', '.rev.as197696.net']
    for end in strip_domain_ends:
        if domain.endswith(end):
            return domain.rstrip(end)
    return domain


def get_reverse_dns(ip: str):
    """ Return reverse DNS (first if multiple found).
    """
    reverse = ''
    try:
        reversename = dns.reversename.from_address(ip)
        if dnspython_handles_resolve:
            answer = dns.resolver.resolve(reversename, 'PTR')
        else:
            answer = dns.resolver.query(reversename, 'PTR')
        if len(answer) > 0:
            reverse = str(answer[0]).rstrip('.')
    except Exception as e:
        pass  # this is ok to have no reverse
    return reverse


def resolve(domain: str, dns_ips: str = None):
    """ Return IPv4 and IPv6 in a list.
    dns_ips: (optional) list of DNS IPs to use for resolution.
    """
    if not domain.endswith('.'):
        domain += '.'
    ips = []
    if dns_ips:
        resolver = dns.resolver.Resolver()
        resolver.nameserver = dns_ips
    else:
        resolver = dns.resolver.get_default_resolver()

    for query_type in ['A', 'AAAA']:
        answers = None
        try:
            if dnspython_handles_resolve:
                answers = resolver.resolve(domain, query_type)
            else:
                answers = resolver.query(domain, query_type)
        except Exception as e:
            pass  # no IPs case will be handled at a higher level

        if answers:
            for ip in answers:
                ip = str(ip)
                if ip not in ips:
                    ips.append(ip)

    return ips


def is_ipv6(ip: str):
    return ':' in ip


def query_ip_reverses(ips: List[str]):
    """ Query reverses with multi threads and return a dict of { ip: reverse }.
    """
    reverses = {}
    for ip in ips:
        if ip == '127.0.0.1':
            reverses[ip] = 'localhost'
            continue

        # Use ThreadPool().apply_async() to set a timeout to the reverse lookup
        try:
            with multiprocessing.pool.ThreadPool() as pool:
                reverse = pool.apply_async(get_reverse_dns, (ip)).get(timeout=DNS_timeout)
                if reverse:
                    reverse = strip_evolix_suffix(reverse)
                reverses[ip] = reverse
        except multiprocessing.TimeoutError:
            pass

        if ip not in reverses or not reverses[ip]:
            reverses[ip] = 'reverse not found'

    return reverses


def find_authoritative_dns(domain: str):
    """ Query the domain SOA and return the list of the authoritative DNS IPs.
    """
    try:
        if dnspython_handles_resolve:
            answers = dns.resolver.resolve(domain, 'SOA')
        else:
            answers = dns.resolver.get_default_resolver().query(domain, 'SOA')
    except:
        # No SOA for the domain (the most common for subdomains) -> query the SOA of the root domain
        root_domain = '.'.join(domain.split('.')[-2:])
        try:
            if dnspython_handles_resolve:
                answers = dns.resolver.resolve(root_domain, 'SOA')
            else:
                answers = dns.resolver.get_default_resolver().query(root_domain, 'SOA')
        except:
            # Debug
            #print('{} SOA record not found'.format(domain))
            return []

    authoritative_ips = []
    for rdata in answers:
        # As SOA mname is a domain, perform another DNS query to get its IP
        ips = resolve(str(rdata.mname))
        if ips:
            authoritative_ips.extend(ips)

    return authoritative_ips


def strip_comments(string: str):
    """ Return string with any # comment removed."""
    return string.split('#')[0]


def to_str(data):
    """ Convert data to str.
    """
    if isinstance(data, list):
        return map(str, sorted(data))
    else:
        return str(data)


def is_naive_datetime(dt: datetime):
    """ Return true if a datetime object is "timezone naive".
    """
    return dt.tzinfo == None or dt.tzinfo.utcoffset(dt) == None


def get_main_domain(domain: str):
    """ Return main domain without subdomain.
    Example:
    - input 'www.example.com' will return 'example.com'.
    """
    splitted = domain.strip('.').split('.')[-2:]
    return '.'.join(splitted)


def get_sub_domain(domain: str):
    """ Return subdomain without main domain.
    Example:
    - input 'dev.www.example.com' will return 'dev.www'.
    """
    splitted = domain.strip('.').split('.')[:-2]
    return '.'.join(splitted)


def sorted_domains(domains_summaries: Dict[str, DomainSummary]):
    """ Returns the list sorted :
    1. root domain
    2. sub-domain (if there are multiple sub-domains, they are taken as a whole, see get_sub_domain())
    """
    s = sorted(domains_summaries, key = get_sub_domain)
    return sorted(s, key = get_main_domain)


def sorted_domains_by_dns_check_result(domains_summaries: Dict[str, DomainSummary]):
    """ Returns the list sorted :
    1: DNS check result
    2. root domain
    3. sub-domain (if there are multiple sub-domains, they are taken as a whole, see get_sub_domain())
    """
    s = sorted(domains_summaries, key = get_sub_domain)
    s = sorted(s, key = get_main_domain)
    return sorted(s, key = lambda domain: domains_summaries[domain].dns_check_result.status)


def sorted_domains_by_http_challenge_result(domains_summaries: Dict[str, DomainSummary]):
    """ Returns the list sorted :
    1: HTTP challenge result
    2. root domain
    3. sub-domain (if there are multiple sub-domains, they are taken as a whole, see get_sub_domain())
    """
    s = sorted(domains_summaries, key = get_sub_domain)
    s = sorted(s, key = get_main_domain)
    return sorted(s, key = lambda domain: domains_summaries[domain].http_challenge_result.status)


def sorted_certificates_by_path(certificates: List[Certificate]):
    """ Return Certificates sorted by path.
    """
    return sorted(certificates, key = lambda cert: cert.path)


def read_conf_file(file_path: str, regex = None): # regex: re.Pattern needs Python > 3.5
    """ Generic configuration reader.
    Strip empty lines and comments.
    If regex is provided, return a list of tuples. Each tuple contain the group matches.
    Example: [
        (group1, group2, …),
        …
    ]
    Else, return a list of striped lines of type string.
    """
    # Touch configuration file, in case of missing file
    if not os.path.exists(file_path):
        open(file_path, 'a').close()

    cleaned_lines = []
    with open(file_path, encoding='utf-8') as f:
        for line in f:
            cleaned_line = strip_comments(line).strip()
            if cleaned_line:
                if regex:
                    match = regex.fullmatch(cleaned_line)
                    if match:
                        cleaned_lines.append(match.groups())
                    else:
                        print_warning('Malformed configuration line \'{}\' in {}.'.format(cleaned_line, file_path))
                else:
                    cleaned_lines.append(cleaned_line)
    return cleaned_lines



"""
HaProxy WIP, standby for now, maybe for version 2
"""


#def list_haproxy_acl_domains():
#    """ Parse HaProxy config file in search of domain ACLs or files containing list of domains.
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
#    """ Process a file containing a list of domains :
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


#def list_haproxy_certificates_domains():
#    """ Return the domains present in HaProxy SSL certificates.
#    Return a dict containing:
#    - key: domain (from domains_file_path)
#    - value: a list of strings 'haproxy_certs:cert_path:CN|SAN'
#    """
#    print_debug('Listing HaProxy certificates domains')
#
#    sources = []
#
#    # Is HaProxy installed?
#    if not os.path.isfile(haproxy_conf_path):
#        print_warning('{} not found'.format(haproxy_conf_path))
#        return sources
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
#        #print('echo "show ssl cert" | socat stdio {}'.format(socket))
#        stdout, stderr, rc = execute('echo "show ssl cert" | socat stdio {}'.format(socket), shell=True)
#
#        for cert_path in stdout:
#            if cert_path.strip().startswith('#'):
#                continue
#            if os.path.isfile(cert_path):
#                domains_to_add = parse_certificate_domains(cert_path, 'haproxy_certs')
#                sources.extend(domains_to_add)
#
#    else:
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
#                domains_to_add = parse_certificate_domains(cert_path, 'haproxy_certs')
#            elif os.path.isdir(cert_path):
#                domains_to_add = list_certificates_domains(p, 'haproxy_certs')
#            sources.extend(domains_to_add)
#
#    return sources
#
#
#def does_haproxy_support_show_ssl_cert():
#    """ Return True if HaProxy version supports 'show ssl cert' command (version >= 2.2)."""
#
#    stdout, stderr, rc = execute('dpkg-query --show haproxy', shell=True)
#
#    supports_show_ssl_cert = False
#
#    if rc == 0:
#        for line in stdout:
#            # Line format: PACKAGE VERSION
#            words = line.strip().split()
#            if words[0] == 'haproxy':
#                major, minor = words[1].split('.')[:2]
#                if int(major) >= 2 and int(minor) >= 2:
#                    supports_show_ssl_cert = True
#
#    return supports_show_ssl_cert
#
#
#def get_haproxy_stats_socket():
#    """ Return HaProxy stats socket."""
#
#    with open(haproxy_conf_path, encoding='utf-8') as f:
#        line_number = 0
#        for line in f.readlines():
#            words = line.strip().split()
#            if len(words) >= 3 and words[0] == 'stats' and words[1] == 'socket':
#                return words[2]
#
#    return None


## Entry point
if __name__ == '__main__':
    program_name = os.path.splitext(os.path.basename(__file__))[0]
    main(sys.argv[1:])

