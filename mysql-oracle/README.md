# mysql

Install MySQL (from Oracle)

## Tasks

Tasks are extracted in several files, included in `tasks/main.yml` :

* `packages.yml` : packages installation ;
* `users.yml` : replacement of `root` user by `mysqladmin` user ;
* `config.yml` : configurations ;
* `datadir.yml` : data directory customization ;
* `tmpdir.yml` : temporary directory customization ;
* `nrpe.yml` : `nrpe` user for Nagios checks ;
* `munin.yml` : Munin plugins ;
* `log2mail.yml` : log2mail patterns ;
* `utils.yml` : useful tools.

## Available variables

* `mysql_replace_root_with_mysqladmin`: switch from `root` to `mysqladmin` user or not ;
* `mysql_thread_cache_size`: number of threads for the cache ;
* `mysql_innodb_buffer_pool_size`: amount of RAM dedicated to InnoDB ;
* `mysql_custom_datadir`: custom datadir
* `mysql_custom_tmpdir`: custom tmpdir.
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).
* `general_scripts_dir`: general directory for scripts installation (default: `/usr/local/bin`).
* `mysql_scripts_dir`: email address to send Log2mail messages to (default: `general_scripts_dir`).
* `mysql_force_new_nrpe_password` : change the password for NRPE even if it exists already (default: `False`).
* `mysql_restart_if_needed` : should the restart handler be executed (default: `True`)

NB : changing the _datadir_ location can be done multiple times, as long as it is not restored to the default initial location, (because a symlink is created and can't be switched back, yet).

## Misc

We use the `mysql-apt-config` package from Oracle to configure APT sources. It is used right from the role since there is no apparent stable URL to download it from Oracle servers. We should verify from time to time if a new version is available to update the .deb in the role.

The MySQL debian package made by Oracle doesn't work with systemd out of the box. We've used the `mysql-systemd-start` script and the systemd unit made by Debian for the "mysql-5.7" package (currently only available for Sid).

On Stretch, "mytop" is not packages anymore (only provided by "mariadb-client-10.1"). We're using the version from the "mytop" package (currently only available for Sid).
