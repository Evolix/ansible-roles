Minifirewall
=========

Minifirewall is shellscripts for easy firewalling on a standalone server
we used netfilter/iptables http://netfilter.org/ designed for recent Linux kernel
See https://gitea.evolix.org/evolix/minifirewall

## Install

~~~
install --mode 0700 minifirewall /etc/init.d/minifirewall
install --mode 0600 minifirewall.conf /etc/default/minifirewall
mkdir --mode 0700 /etc/minifirewall.d
~~~

## Config

Edit /etc/default/minifirewall file:

* If your interface is not `eth0`, change `INT` variable
* If you don't use IPv6, set `IPv6='off'`
* Modify `INTLAN` variable, probably with your `<IP>/32` or your local network if you trust it
* Set your trusted and privilegied IP addresses in `TRUSTEDIPS` and `PRIVILEGIEDIPS` variables
* Authorize your **public** services with `SERVICESTCP1` and `SERVICESUDP1` variables
* Authorize your **semi-public** services (only for `TRUSTEDIPS` and `PRIVILEGIEDIPS` ) with `SERVICESTCP2` and `SERVICESUDP2` variables
* Authorize your **private** services (only for `TRUSTEDIPS` ) with `SERVICESTCP3` and `SERVICESUDP3` variables
* Configure your authorizations for external services : DNS, HTTP, HTTPS, SMTP, SSH, NTP
* Add your specific rules

### Docker

To use minifirewall with Docker you need to change the variable `DOCKER='on'`
Then, authorisation for public/semi-public/private ports will also work for dockerized services

**WARNING** : When the port mapping on the host is different than in the container (ie: listen on :8090 on the host, but the service in the container listen on :8080)
you need to use the port used by the container (ie: 8080) in the public/semi-public/private port list

## Usage

~~~
/etc/init.d/minifirewall start/stop/restart
~~~

If you want to add minifirewall in boot sequence, add the start command to `/usr/share/scripts/alert5`.

## License

This is an [Evolix](https://evolix.com) project and is licensed
under the GPLv3, see the [LICENSE](LICENSE) file for details.
