# Evodomains

Evodomains is a Python script to discover a server's domains and perform somes checks.


## Usage

~~~
$ python3 evodomains.py --help

usage: evodomains [-h] [-l LOCATION [LOCATION ...]] [-d] [-n] [--no-pager] [--no-header] [--non-interactive] [--color] [-o OUTPUT] [--expiration-warn EXPIRATION_WARN]
                  [--expiration-crit EXPIRATION_CRIT] [--valid-domains] [-q] [-v] [-V]
                  [ACTION] [DOMAIN ...]

positional arguments:
  ACTION                Available actions: list: list the domains, check-dns: check the domains DNS, http-challenge: do HTTP challenges in local /var/lib/letsencrypt/.well-known/acme-
                        challenge like Let's Encrypt (vhosts must be configured accordingly), check-certs: check the TLS certificates, help: show this help
  DOMAIN                Provide directly domain names for check-dns action. In this case, the domains discovery is skipped.

options:
  -h, --help            show this help message and exit
  -l LOCATION [LOCATION ...], --location LOCATION [LOCATION ...]
                        Location(s) to search domains, space-separated. Values can be: 'apache', 'nginx', 'haproxy' (certificates only), 'certificates' (in /etc/ssl/certs, Haproxy, Certbot
                        and Evoacme), 'extra-domains' (listed in file /etc/evolinux/evodomains/extra-domains), 'extra-certs' (listed in file /etc/evolinux/evodomains/extra-certs), a
                        directory path (certificates only, not recursive) or an enabled vhost name. Default is 'apache nginx certificates extra-domains'
  -d, --debug           Print debug to stderr and enable --verbose
  -r, --reverse         Show reverse DNS instead of IPs
  --no-pager            Do not pipe output into a pager
  --no-header           Do not print header when default output (--output table)
  --non-interactive     Run without confirmation messages and disable colors (implies --no-pager as well)
  --color               Force color (that are desactivated with pipes, redirections or non-interactive shells)
  -o OUTPUT, --output OUTPUT
                        Output format, values: table (default), json, nrpe (only with check-dns and check-certs actions)
  --expiration-warn EXPIRATION_WARN
                        Threshold for certificate "expires soon" warning message, in days, default: 15
  --expiration-crit EXPIRATION_CRIT
                        Threshold for certificate "expires very soon" critical message, in days, default: 7
  --valid-domains       Check only certificates containing domains that are validated by check-dns action (only with check-certs action)
  -q, --no-warnings     Quiet, suppress warnings (useful for --output json)
  -v, --verbose         With check-dns, print also OK domains; with --output json, print details for each domain
  -V, --version         show program's version number and exit
~~~


## Installation and update

### With Ansible

Not in production.

~~Use the role [`evodomains`](https://forge.evolix.net/evolix/ansible-roles/src/branch/stable/evodomains) of [`ansible-role` repository](https://forge.evolix.net/evolix/ansible-roles).~~


### Manual installation or update

Install dependencies:

~~~
apt install python3 python3-tabulate python3-cryptography python3-dnspython python3-requests
~~~

Note : the following instructions are the same for installation and update.


Clone the repo in the directory of your choice:

~~~
cd /tmp
git clone https://forge.evolix.net/evolix/evodomains.git
cd /tmp/evodomains
git switch main
~~~

Execute as root:

~~~
install -m 700 ./evodomains.py /usr/local/bin/evodomains
if [ -d '/etc/bash_completion.d' ]; then
    install -m 644 ./evodomains_completion.sh /etc/bash_completion.d/evodomains_completion
fi

mkdir -p /usr/local/lib/nagios/plugins/
install -m 750 -g nagios ./check_domains.sh /usr/local/lib/nagios/plugins/check_domains
install -m 750 -g nagios ./check_certs.sh /usr/local/lib/nagios/plugins/check_certs

mkdir -p "/etc/evolinux/evodomains"
for name in "ignored_domains_check.list" "included_domains_check.list" "allowed_ips_check.list" "wildcard_replacements"; do
    touch "/etc/evolinux/evodomains/${name}"
done

cd ~
rm -rf /tmp/evodomains/
~~~


## Configuration

### Ignore domains

`evodomains` looks for domains in Apache, Nginx and some default SSL certificate paths (Let's Encrypt, `etc/ssl/certs`).

To exclude domains from `evodomains check-dns` output, add them to `/etc/evolinux/evodomains/ignored_domains_check.list`.

Format: one domain per line, regex and wildcards not supported.


### Add domains

`evodomains` looks for domains in Apache, Nginx and some default SSL certificate paths (Let's Encrypt, `etc/ssl/certs`).

To add other domains, add them to `/etc/evolinux/evodomains/included_domains_check.list`

Format: one domain per line, regex and wildcards not supported.


### Allow domains to point to external IPs

By default, `evodomains check-dns` allows only hostname IPs. All other are reported as wrong DNS pointing.

To allow more IPs, add them to `/etc/evolinux/evodomains/allowed_ips_check.list`

Format: one IP per line, regex and wildcards not supported.


### Define a wildcard replacement domain to check

By default, wildcards like `*.example.com` are not checked.

If you want `evodomains check-dns` to check a domain for a wildcard, add it to `/etc/evolinux/evodomains/wildcard_replacements`.

Format: on pair per line, like this : `WILDCARD_DOMAIN REPLACEMENT_DOMAIN`.


## Packaging

**Warning: section and branch not maintained.**

Clone the repository.

Warning: the package will be built into the parent directory.

Execute:

~~~
$ git switch debian
$ debuild -us -uc
~~~

Then you can use the package `../evodomains_VERSION_all.deb`
