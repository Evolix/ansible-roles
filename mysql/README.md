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

* `mysql_replace_root_with_mysqladmin`: switch from `root` to `mysqladmin` user or not ;
* `mysql_thread_cache_size`: number of threads for the cache ;
* `mysql_innodb_buffer_pool_size`: amount of RAM dedicated to InnoDB ;
* `mysql_custom_datadir`: custom datadir
* `mysql_custom_tmpdir`: custom tmpdir.

NB : changing the _datadir_ location can be done multiple times, as long as it is not restored to the default initial location, (because a symlink is created  and can't be switched back, yet).
