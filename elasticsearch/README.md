# elasticsearch

Install Elasticsearch.

## Tasks

Tasks are extracted in several files, included in `tasks/main.yml` :

* `packages.yml` : install packages ;
* `configuration.yml` : configure the service;
* `bootstrap_checks.yml` : deal with bootstrap checks;
* `datadir.yml` : data directory customization ;
* `tmpdir.yml` : temporary directory customization ;

## Available variables

* `elasticsearch_cluster_name`: cluster name ;
* `elasticsearch_cluster_members:` members of a cluster (ex: '["10.0.0.1", "10.0.0.2", "10.0.0.3"]') (default: `Null`) ; 
* `elasticsearch_minimum_master_nodes:` minimum of master nodes (the best practice is to have "number of elasticsearch_cluster_members / 2 + 1" as value) (default: `Null`) ; 
* `elasticsearch_node_name`: node name, defaults to hostname ;
* `elasticsearch_network_host`: which interfaces to bind to ;
* `elasticsearch_network_publish_host`: which interface to publish for node-to-node communication (default: `Null`) ;
* `elasticsearch_http_publish_host`: which interface to publish for clients (default: `Null`) ;
* `elasticsearch_custom_datadir`: custom datadir ;
* `elasticsearch_custom_tmpdir`: custom tmpdir ;
* `elasticsearch_jvm_xms`: mininum heap size reserved for the JVM (default: `2g`).
* `elasticsearch_jvm_xmx`: maximum heap size reserved for the JVM (default: `2g`).
* `elasticsearch_restart_on_upgrade`: restart the service after package upgrade (default: `true`)

By default, Elasticsearch will listen to the local interface (`_local_` cf. https://www.elastic.co/guide/en/elasticsearch/reference/5.0/important-settings.html#network.host).

## Curator

Curator can be installed. :

* `elasticsearch_curator` : enable the package installation (default: `False`) ;

## Head plugin

The "head" plugin can be installed :

* `elasticsearch_plugin_head` : enable the plugin installation (default: `False`) ;
* `elasticsearch_plugin_head_basedir`: base directory (default : `/var/www`) ;
* `elasticsearch_plugin_head_clone_name`: directory name for git clone.

To use this plugin, you have to run the built-in webserver (using Grunt/NodeJS), or point a webserver to the path. More details here : https://github.com/mobz/elasticsearch-head#running-with-built-in-server

For example, to run the built-in server, with "www-data" user :

```
# sudo -u www-data bash -c 'cd /var/www/elasticsearch-head && grunt server'
```
