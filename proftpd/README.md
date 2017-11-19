# profptd

Installation and basic configuration of ProFTPd

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `proftpd_hostname`: hostname (default: `ansible_hostname`)
* `proftpd_fqdn`: fully qualified domain name (default: `ansible_fqdn`)
* `proftpd_default_address` : address for the server to listen on (default: `[]`)
* `proftpd_port` : port for the control socket (default: `21`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
