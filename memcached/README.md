# Memcached

Installation and basic configuration of memcached

## Tasks

Minimal configuration is in `tasks/main.yml`

## Available variables

Main variables are :

* `memcached_mem`: amount of memory (default: `64`) ;
* `memcached_user`: running user (default: `nobody`) ;
* `memcached_port`: opened port (default: `11211`) ;
* `memcached_bind_interface`: interface to listen to (default: `127.0.0.1`) ;
* `memcached_connections`: number of simultaneous incoming connections (default: `1024`) ;

The full list of variables (with default values) can be found in `defaults/main.yml`.
