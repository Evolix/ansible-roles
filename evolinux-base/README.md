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

* `evolinux_delete_nfs`: delete NFS tools (default: `True`)
* `evolinux_ntp_server`: custom NTP server host or IP (default: `Null`)
* `evolinux_additional_packages`: optional additional packages to install (default: `[]`)
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `apt_alert_email`: email address to send APT messages to (default: `general_alert_email`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).

The full list of variables (with default values) can be found in `defaults/main.yml`.
