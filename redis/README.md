# munin

Installation and basic configuration of Redis.

This role is based on https://github.com/geerlingguy/ansible-role-redis

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `redis_daemon`: name of the process ;
* `redis_conf_dir`: config directory ;
* `redis_port`: listening TCP port ;
* `redis_bind_interface`: listening IP address ;
* `redis_password`: password for redis. Empty means no password ;
* `redis_socket_dir`: Unix socket directory ;
* `redis_log_level`: log verbosity ;
* `redis_log_dir`: log file directory.

The full list of variables (with default values) can be found in `defaults/main.yml`.
