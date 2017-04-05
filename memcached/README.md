# PHP-FPM

Installation and basic configuration of memcached

## Tasks

Minimal configuration is in `tasks/main.yml`

## Available variables

Main variables are :

* `memcached_logfile`: path of the log file ;
* `memcached_mem`: amount of memory ;
* `memcached_user`: running user ;
* `memcached_bind_interface`: interface to listen to ;
* `memcached_connections`: number of simultaneous incoming connections ;

The full list of variables (with default values) can be found in `defaults/main.yml`.
