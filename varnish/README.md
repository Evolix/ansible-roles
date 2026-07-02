# Varnish

Installation and basic configuration of Varnish

## Tasks

Everything is in the `tasks/main.yml` file.

## Variables

* `thread_pools` : number of thread to use (default to number of vCPU)
* `malloc` : amount of memory to allocate (default: `2G`)
* `varnish_wait_for_haproxy` : tell if varnish should be started only after haproxy has been (haproxy service must be configured)
