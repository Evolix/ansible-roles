# squid

Installation and configuration of Squid

## Tasks

Everything is in the `tasks/main.yml` file.

A blank file is created at `/etc/squid3/whitelist-custom.conf` to add addresses in the whitelist.

## Available variables

* `squid_address` : IP address for internal/outgoing traffic (default: Ansible detected IPv4 address) ;
* `squid_whitelist_items` : list of URL to add to the whitelist (default: `[]`) ;
* `squid_localproxy_enable` : enable configuration for squid as local proxy (default: False) ;
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`) ;
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).


The full list of variables (with default values) can be found in `defaults/main.yml`.

**Warning** : if squid has been installed with `squid_localproxy_enable: False`, it can't be simply switched to `True` and re-run.
You have to purge the squid package, remove the configuration `rm -rf /etc/squid* /etc/default/squid*` and then re-run the playbook.
