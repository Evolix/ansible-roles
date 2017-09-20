# fail2ban

Install Fail2ban.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `fail2ban_alert_email`: email address for messages sent to root (default: `general_alert_email`).
* `fail2ban_ignore_ips`: list of IPs to ignore (default: empty).

The full list of variables (with default values) can be found in `defaults/main.yml`.
