# kibana

Install Kibana.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `kibana_server_host` : Specifies the address to which the Kibana server will bind (default: `127.0.0.1`) ;
* `kibana_server_basepath` : where to mount the application (default: empty) ;
* `kibana_proxy_nginx` : configure an Nginx proxy (not enabled) for Kibana (default: `False`) ;
* `kibana_proxy_domain` : domain to use for the proxy ;
* `kibana_proxy_ssl_cert` : certificate to use for the proxy ;
* `kibana_proxy_ssl_key` : private key to use for the proxy ;

By default, Kibana will bind to localhost:5601.
