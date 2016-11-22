# kibana

Install Kibana.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

The only variables are derived from gathered facts.

By default, Kibana will bind to localhost:5601.
If Nginx is installed, a typical proxy configuration is copied into `/etc/nginx/sites-available`. It can be tweeked and enabled by hand.
