# Apache

Install Apache

## Tasks

Everything is in the `tasks/main.yml` file for now.

## Available variables

Main variables are :

* `apache_private_ipaddr_whitelist_present` : list of IP addresses to have in the private whitelist ;
* `apache_private_ipaddr_whitelist_absent` : list of IP addresses **not** to have in the whitelist;
* `apache_private_htpasswd_present` : list of users to have in the private htpasswd ;
* `apache_private_htpasswd_absent` : list of users to **not** have in the private htpasswd.

The full list of variables (with default values) can be found in `defaults/main.yml`.
