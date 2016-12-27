# evolinux-base

Various tasks for Evolinux setup.

## Tasks

* `system.yml` :
* `apt.yml` :
* `install_tools.yml` :
* `root.yml` :
* `logs.yml` :

## Available variables

Main variables are :

* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `apt_alert_email`: email address to send APT messages to (default: `general_alert_email`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).
* `postfix_alias_email`: email address for messages sent to root (default: `general_alert_email`) ;
* `evolinux_apt_hooks`: install APT hooks (default: `True`)
* `evolinux_apt_remove_aptitude`: uninstall aptitude (default: `True`)
* `evolinux_delete_nfs`: delete NFS tools (default: `True`)
* `evolinux_ntp_server`: custom NTP server host or IP (default: `Null`)
* `evolinux_additional_packages`: optional additional packages to install (default: `[]`)
* `evolinux_postfix_slow_transports_enabled`: configure slow transports (default: `True`) ;
* `evolinux_postfix_remove_exim`: remove Exim4 packages (default: `True`) ;

The full list of variables (with default values) can be found in `defaults/main.yml`.
