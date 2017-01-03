# evolinux-base

Various tasks for Evolinux setup.

## Tasks

* `hostname` :
* `kernel` :
* `apt` :
* `fstab` :
* `packages` :
* `system` :
* `root` :
* `ssh` :
* `postfix` :
* `logs` :
* `default_www` :
* `hardware` :
* `provider_online` :
* `provider_orange_fce` :

## Available variables

Each tasks group is included in the `main.yml` file with a condition based on a variable like `evolinux_hostname_include` (mostly `True` by default). The variables can be set to `False` to disable a . Finer grained tasks disabling is done in each group of tasks.

Main variables are:

* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `apt_alert_email`: email address to send APT messages to (default: `general_alert_email`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).
* `postfix_alias_email`: email address for messages sent to root (default: `general_alert_email`) ;
* `evolinux_apt_upgrade`: upgrade packages (default: `True`)
* `evolinux_apt_hooks`: install APT hooks (default: `True`)
* `evolinux_apt_remove_aptitude`: uninstall aptitude (default: `True`)
* `evolinux_delete_nfs`: delete NFS tools (default: `True`)
* `evolinux_ntp_server`: custom NTP server host or IP (default: `Null`)
* `evolinux_additional_packages`: optional additional packages to install (default: `[]`)
* `evolinux_postfix_purge_exim`: purge Exim packages (default: `True`) ;
* `evolinux_ssh_password_auth_addresses`: list of addresses that can authenticate with a password (default: `[]`)
* `evolinux_ssh_disable_root`: disable SSH access for root (default: `True`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
