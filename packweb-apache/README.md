# packweb-apache

Install the web pack, with Apache.

## Tasks

See `tasks/main.yml`.

## Available variables

Main variables are :

* `packweb_enable_evoadmin_vhost` : enable VirtualHost for evoadmin (web interface to create web accounts)
* `packweb_mysql_variant`: which Variant to use for MySQL (`debian` or `oracle`, default: `debian`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
