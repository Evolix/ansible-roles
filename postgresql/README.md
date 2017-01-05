# PostgreSQL

Installation and basic configuration of PostgreSQL.

## Tasks

Tasks are in several files, included in `tasks/main.yml` :

* `packages.yml` : packages installation ;
* `config.yml` : configurations ;
* `nrpe.yml` : `nrpe` user for Nagios checks ;
* `munin.yml` : Munin plugins ;
* `logrotate.yml` : logrotate configuration.

## Available variables

Main variables are :

* `postgresql_databases`: list of databases for Munin plugins
* `postgresql_shared_buffers`: (default: `4GB`)
* `postgresql_work_mem`: (default: `8MB`)
* `postgresql_random_page_cost`: (default: `1.5`)
* `postgresql_effective_cache_size`: (default: `14GB`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
