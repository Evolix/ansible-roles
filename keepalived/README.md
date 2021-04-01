# keepalived

Install Keepalived

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `keepalived_interface` : Interface used by vrrpd instance (default is the interface reported by ansible_default_ipv4.interface)
* `keepalived_role` : This can be either master or backup (default: `master`)
* `keepalived_router_id` : Number between 0 and 255 used to differentiate multiple instances of vrrpd (default: `42`)
* `keepalived_priority` : Used for electing MASTER, highest priority wins (default : `100` when keepalived_role is set to `master` otherwise `50`)
* `keepalived_ip` : Address added or deleted on change to MASTER/BACKUP. This is mandatory (default: none)
* `keepalived_password` : Password for accessing vrrpd. Should be the same on all machines. This is mandatory (default: none)
