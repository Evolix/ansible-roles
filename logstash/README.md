# logstash

Install Logstash.

## Tasks

Everything is in the `tasks/main.yml` file.

## Variables

* `logstash_jvm_xms`: minimum heap size reserved for the JVM (defaults to 256m).
* `logstash_jvm_xmx`: maximum heap size reserved for the JVM (defaults to 1g).

The pipeline must be configured before starting Logstash.
https://www.elastic.co/guide/en/logstash/5.0/index.html
