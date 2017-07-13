# kibana

Install Kibana.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `kibana_proxy_nginx` : configure an Nginx proxy (not enabled) for Kibana (default: `False`) ;
* `kibana_proxy_domain` : domain to use for the proxy ;
* `kibana_proxy_ssl_cert` : certificate to use for the proxy ;
* `kibana_proxy_ssl_key` : private key to use for the proxy ;

By default, Kibana will bind to localhost:5601.
