# nginx

Install Nginx.

## Tasks

Everything is in the `tasks/main.yml` file.

There are 2 modes : minimal and regular.

The minimal mode is for servers without real web apps, and only access to munin graphs…

The regular mode is for full fledged web services with optimized defaults.

An `ip_whitelist.yml` standalone task file is available to update IP adresses whitelist without rolling the whole role.

## Available variables

Main variables are :

* `nginx_minimal` : very basic install and config (default: `False`) ;
* `nginx_backports` : we can prefer higher version from backports (default: `False`) ;
* `nginx_ipaddr_whitelist_present` : list of IP addresses to have in the private whitelist ;
* `nginx_ipaddr_whitelist_absent` : list of IP addresses **not** to have in the whitelist ;
* `nginx_private_htpasswd_present` : list of users to have in the private htpasswd ;
* `nginx_private_htpasswd_absent` : list of users to **not** have in the private htpasswd.

The full list of variables (with default values) can be found in `defaults/main.yml`.
