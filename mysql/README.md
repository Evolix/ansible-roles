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
* `replication.yml`: install and configure prerequisites for mysql replication, do not forget to set `mysql_bind_address`, `mysql_server_id` and `mysql_log_bin`

## Available variables

* `mysql_variant` : install Oracle's MySQL or MariaDB (default: `oracle`) [Debian 8 only];
* `mysql_replace_root_with_mysqladmin`: switch from `root` to `mysqladmin` user or not ;
* `mysql_replication`: setup all prerequisites for replication.
* `mysql_thread_cache_size`: number of threads for the cache ;
* `mysql_innodb_buffer_pool_size`: amount of RAM dedicated to InnoDB ;
* `mysql_bind_address` : (default: `Null`, default evolinux config is then used) ;
* `mysql_max_connections`: maximum number of simultaneous connections (default: `Null`, default evolinux config is then used) ;
* `mysql_max_connect_errors`: number of permitted successive interrupted connection requests before a host gets blocked (default: `Null`, default evolinux config is then used) ;
* `mysql_table_cache`: (default: `Null`, default evolinux config is then used) ;
* `mysql_tmp_table_size`: (default: `Null`, default evolinux config is then used) ;
* `mysql_max_heap_table_size`: (default: `Null`, default evolinux config is then used) ;
* `mysql_query_cache_limit`: (default: `Null`, default evolinux config is then used) ;
* `mysql_query_cache_size`: (default: `Null`, default evolinux config is then used) ;
* `mysql_server_id`: (default: `Null`, only used with `mysql_replication`, default mysql server id will be used otherwise) ;
* `mysql_custom_datadir`: custom datadir.
* `mysql_custom_tmpdir`: custom tmpdir.
* `general_alert_email`: email address to send various alert messages (default: `root@localhost`).
* `log2mail_alert_email`: email address to send Log2mail messages to (default: `general_alert_email`).
* `general_scripts_dir`: general directory for scripts installation (default: `/usr/local/bin`).
* `mysql_scripts_dir`: email address to send Log2mail messages to (default: `general_scripts_dir`).
* `mysql_force_new_nrpe_password` : change the password for NRPE even if it exists already (default: `False`).
* `mysql_install_libclient`: install mysql client libraries (default: `False`).
* `mysql_restart_if_needed` : should the restart handler be executed (default: `True`)
* `mysql_log_bin`: (default: `Null`, activates binlogs if used with `mysql_replication`) ;
* `mysql_repl_password`: Password hash for replication user, only creates a user if set.
## Notes
Changing the _datadir_ location can be done multiple times, as long as it is not restored to the default initial location, (because a symlink is created and can't be switched back, yet).

When using replication, note that the connections from the client server on the haproxy 8306 and mysql 3306 ports need to be open and the sql servers need to communicate on port 3306.
