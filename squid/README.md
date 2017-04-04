# squid

Installation and configuration of Squid as an outgoing proxy.

## Tasks

Everything is in the `tasks/main.yml` file.

A blank file is created at `/etc/squid3/whitelist-custom.conf` to add addresses in the whitelist.

## Available variables

* `squid_address` : IP address for internal/outgoing traffic (default: Ansible detected IPv4 address) ;
* `squid_whitelist_items` : list of URL to add to the whitelist (default: `[]`) ;
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).

The full list of variables (with default values) can be found in `defaults/main.yml`.
