# OpenVPN

Install and configure OpenVPN, based on [our HowtoOpenVPN wiki](https://wiki.evolix.org/HowtoOpenVPN)

## Tasks

Everything is in the `tasks/main.yml` file.

Here is what this role does :

* Installs and configures OpenVPN
* Installs and configures shellpki
* Authorizes users in shellpki group to use shellpki with sudo
* Configures NAT if minifirewall exists, for Debian only
* Allows connexion to UDP/1194 port publicly in minifirewall if it exists or in PacketFilter for OpenBSD
* Enables IPv4 forwarding with sysctl
* Configures NRPE to check OpenVPN
* Adds a cron to warn about certificates expiration
* Inits the CA and create the server's certificate

NAT allows servers reached through OpenVPN to be reached by the public IP of the OpenVPN server. The public IP of the OpenVPN server must therefore be allowed on the end servers.

Some manual actions are requested at the end of the playbook, to do before finishing the playbook :

* You must check and adjust if necessary the configuration file "/etc/openvpn/server.conf", and then restart the OpenVPN service with "rcctl restart openvpn".
* You must take note of the generated CA password and store it in your password manager.

Finally, you can use `shellpki` to generate client certificates.

## Variables

* `openvpn_lan`: network to use for OpenVPN
* `openvpn_netmask`: netmask of the network to use for OpenVPN
* `openvpn_netmask_cidr`: automatically generated prefix length of the netmask, in CIDR notation

By default, if the server IP is 192.0.2.42, then OpenVPN LAN will be 10.2.42.0/24 (last 2 digit of main IP of server set as 2nd and 3rd digit of OpenVPN LAN).

## Dependencies

* Files in `files/shellpki/*` are gotten from the upstream [shellpki](https://gitea.evolix.org/evolix/shellpki) and must be updated when the upstream is.
