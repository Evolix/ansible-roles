# OpenVPN

Install and configure OpenVPN, based on [our HowtoOpenVPN wiki](https://wiki.evolix.org/HowtoOpenVPN)

## Tasks

Everything is in the `tasks/main.yml` file.
Some manual actions are requested at the end of the playbook, to do before finishing the playbook.

## Variables

* `openvpn_lan`: network to use for OpenVPN
* `openvpn_netmask`: netmask of the network to use for OpenVPN
* `openvpn_netmask_cidr`: automatically generated prefix length of the netmask, in CIDR notation

## TODO

* Make it compatible with OpenBSD
* See TODO tasks in tasks/main.yml
