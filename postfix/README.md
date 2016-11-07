# postfix

Install Postfix

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `postfix_alias_email`: email address for messages sent to root (default: `general_alert_email`) ;
* `postfix_slow_transports_enabled`: configure slow transports (default: `True`) ;
* `postfix_remove_exim`: remove Exim4 packages (default: `True`) ;

The full list of variables (with default values) can be found in `defaults/main.yml`.
