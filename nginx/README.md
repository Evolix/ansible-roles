# nginx

Install Nginx.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `nginx_worker_processes` : number of worker processes ;
* `nginx_default_redirect_url` : URL to redirect to in case of error ;
* `nginx_ipaddr_whitelist_present` : list of IP addresses to have in the whitelist.
* `nginx_ipaddr_whitelist_absent` : list of IP addresses **not** to have in the whitelist.

The full list of variables (with default values) can be found in `defaults/main.yml`.
