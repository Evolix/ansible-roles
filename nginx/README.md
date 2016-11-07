# nginx

Install Nginx.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `nginx_private_ipaddr_whitelist_present` : list of IP addresses to have in the private whitelist ;
* `nginx_private_ipaddr_whitelist_absent` : list of IP addresses **not** to have in the whitelist ;
* `nginx_private_htpasswd_present` : list of users to have in the private htpasswd ;
* `nginx_private_htpasswd_absent` : list of users to **not** have in the private htpasswd.

The full list of variables (with default values) can be found in `defaults/main.yml`.
