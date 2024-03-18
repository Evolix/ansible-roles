# profptd

Installation and basic configuration of ProFTPd

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `proftpd_hostname`: hostname (default: `ansible_hostname`)
* `proftpd_fqdn`: fully qualified domain name (default: `ansible_fqdn`)
* `proftpd_default_address` : address for the server to listen on (default: `[]`)
* `proftpd_port` : port for the control socket (default: `21`)

The full list of variables (with default values) can be found in `defaults/main.yml`.

## Accounts management

Proftpd accounts can be maintened with the `proftpd_accounts` var, it can be set in inventory/host_vars/inventory_hostname :

~~~
proftpd_accounts:
- { name: 'ftp1', home: '/srv/data/ftp1', uid: 116, gid: 65534 }
- { name: 'ftp2', home: '/srv/data/ftp2', uid: 116, gid: 65534 }
~~~

The password will be randomly generated and printed to the screen the first time you run the task.

You can force is value by set the `password` field with the hashed version of your password.

eg. for "test" password hashed with sha512 :

~~~
proftpd_accounts:
- { name: 'ftp1', home: '/srv/data/ftp1', uid: 116, gid: 65534, password: '$6$/Yy0b0No3GWh$3ZY1GZFI25eyQDBrANyHw.NFPqPqdg6sCi89nM/aNitmESZ2jGfROveS5xowy.WjX9tMC7.KPoabKPyxOpBJY0' }
~~~

For generate the sha512 version of yours password :

~~~
printf "test" | mkpasswd --stdin --method=sha-512
~~~

## Add whitelist ip for accounts

If you want add an filtering by ip for accounts, you have to enabled variable `proftpd_sftp_enable_user_whitelist` and add variable `proftpd_sftp_ips_whitelist` and a group by accounts.

Example :

~~~
proftpd_sftp_enable_user_whitelist : True

proftpd_sftp_ips_whitelist:
  foo: ['127.0.0.1', '192.168.0.1']

proftpd_accounts:
- { name: 'ftp3', home: '/home/ftp3/', uid: 116, gid: 65534, group: 'foo', password: '$6$/Yy0b0No3GWh$3ZY1GZFI25eyQDBrANyHw.NFPqPqdg6sCi89nM/aNitmESZ2jGfROveS5xowy.WjX9tMC7.KPoabKPyxOpBJY0' }
~~~
