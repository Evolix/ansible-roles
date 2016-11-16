# elasticsearch-plugin-head

Install Head (Elasticsearch plugin).

## Tasks

Everything is in the `tasks/main.yml` file.

## Variables

* `elasticsearch_plugin_head_basedir`: base directory (default : `/var/www`) ;
* `elasticsearch_plugin_head_clone_name`: directory name for git clone.

## Misc

To use this plugin, you have to run the built-in webserver (using Grunt/NodeJS), or point a webserver to the path. More details here : https://github.com/mobz/elasticsearch-head#running-with-built-in-server

For example, to run the built-in server, with "www-data" user :

```
# sudo -u www-data bash -c 'cd /var/www/elasticsearch-head && grunt server'
```
