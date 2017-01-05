# munin

Installation and basic configuration of Redis.

This role is based on https://github.com/geerlingguy/ansible-role-redis

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `redis_daemon`: name of the process ;
* `redis_conf_path`: config file location ;
* `redis_port`: listening TCP port ;
* `redis_bind_interface`: listening IP address ;
* `redis_unixsocket`: Unix socket ;
* `redis_loglevel`: log verbosity ;
* `redis_logfile`: log file location.

The full list of variables (with default values) can be found in `defaults/main.yml`.
