# profptd

Installation and basic configuration of ProFTPd

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `proftpd_hostname`: hostname (default: `ansible_hostname`)
* `proftpd_fqdn`: fully qualified domain name (default: `ansible_fqdn`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
