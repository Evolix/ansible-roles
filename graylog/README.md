# Graylog

Installation and basic configuration of Graylog.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `graylog_version`: the Graylog version to install (default: `5.0`),
* `graylog_listen_ip`: the listen IP for Graylog (default: `"127.0.0.1"`),
* `graylog_listen_port`: the listen port for Graylog (default: `9000`),
* `graylog_custom_datadir`: the Graylog data directory (default: `""`, the empty string).

The full list of variables (with default values) can be found in `defaults/main.yml`.
