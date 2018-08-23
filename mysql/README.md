# mysql

Install MySQL

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

* `mysql_variant` : install Oracle's MySQL or MariaDB (default: `oracle`) [Debian 8 only];
* `mysql_replace_root_with_mysqladmin`: switch from `root` to `mysqladmin` user or not ;
* `mysql_bind_address` : (default: `127.0.0.1`) ;
* `mysql_thread_cache_size`: number of threads for the cache ;
* `mysql_innodb_buffer_pool_size`: amount of RAM dedicated to InnoDB ;
* `mysql_max_connections`: maximum number of simultaneous connections (default: `250`) ;
* `mysql_max_connect_errors`: number of permitted successive interrupted connection requests before a host gets blocked (default: `10`) ;
* `mysql_table_cache`: (default: `64`) ;
* `mysql_tmp_table_size`: (default: `128M`) ;
* `mysql_max_heap_table_size`: (default: `128M`) ;
* `mysql_query_cache_limit`: (default: `8M`) ;
* `mysql_query_cache_size`: (default: `256M`) ;
* `mysql_custom_datadir`: custom datadir.
* `mysql_custom_tmpdir`: custom tmpdir.
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).
* `general_scripts_dir`: general directory for scripts installation (default: `/usr/local/bin`).
* `mysql_scripts_dir`: email address to send Log2mail messages to (default: `general_scripts_dir`).
* `mysql_force_new_nrpe_password` : change the password for NRPE even if it exists already (default: `False`).
* `mysql_install_libclient`: install mysql client libraries (default: `False`).

NB : changing the _datadir_ location can be done multiple times, as long as it is not restored to the default initial location, (because a symlink is created and can't be switched back, yet).
