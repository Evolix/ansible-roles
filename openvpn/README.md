# OpenVPN

Install and configure OpenVPN, based on [our HowtoOpenVPN wiki](https://wiki.evolix.org/HowtoOpenVPN)

## Tasks

Everything is in the `tasks/main.yml` file.
Some manual actions are requested at the end of the playbook, to do before finishing the playbook.

Here is a copy of what is requested :

* You have to manually create the CA on the server with `shellpki init server.example.com`. The command will ask you to create a password, and will ask you again to give the same one several times.
* You have to manually generate the CRL on the server with `openssl ca -gencrl -keyfile /etc/shellpki/cakey.key -cert /etc/shellpki/cacert.pem -out /etc/shellpki/crl.pem -config /etc/shellpki/openssl.cnf`. The previously created password will be asked.
* You have to manually create the server's certificate with `shellpki create server.example.com`.
* You have to adjust the config file `/etc/openvpn/server.conf` for the following parameters : `local` (to check), `cert` (to check), `key` (to add), `server` (to check), `push` (to complete if needed).
* Finally, you can (re)start the OpenVPN service with `systemctl restart openvpn@server.service` on Debian, or `rcctl restart openvpn` on OpenBSD.

Then, you can use `shellpki` to generate client certificates.

## Variables

* `openvpn_lan`: network to use for OpenVPN
* `openvpn_netmask`: netmask of the network to use for OpenVPN
* `openvpn_netmask_cidr`: automatically generated prefix length of the netmask, in CIDR notation

## TODO

* See TODO tasks in tasks/*.yml
