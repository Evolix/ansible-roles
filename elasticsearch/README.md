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
* `elasticsearch_node_name`: node name, defaults to hostname ;
* `elasticsearch_network_host`: which interfaces to bind to ;
* `elasticsearch_network_publish_host`: which interface to publish ;
* `elasticsearch_custom_datadir`: custom datadir
* `elasticsearch_custom_tmpdir`: custom tmpdir

By default, Elasticsearch will listen to the public interfaces (`_site_` cf. https://www.elastic.co/guide/en/elasticsearch/reference/5.0/important-settings.html#network.host), so you will have to secure it, with firewall rules for example.
