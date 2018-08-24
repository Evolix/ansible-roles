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
* `memcached_instance_name`: use this to set up multiple memcached instances (default: `False`) ;

The full list of variables (with default values) can be found in `defaults/main.yml`.

## Multiple intances

When using memcached_instance_name variable, you can set up multiple memcached instances :

  roles:
   - { role: memcached, memcached_instance_name: "instance1" }
   - { role: memcached, memcached_instance_name: "instance2", memcached_port: 11212 }
