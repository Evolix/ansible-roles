Minifirewall
=========

Minifirewall is shellscripts for easy firewalling on a standalone server
we used netfilter/iptables http://netfilter.org/ designed for recent Linux kernel
See https://gitea.evolix.org/evolix/minifirewall

## Install

~~~
install --mode 0700 minifirewall.sh /usr/local/sbin/minifirewall
install --mode 0700 minifirewall.init.sh /etc/init.d/minifirewall
install --mode 0600 minifirewall.conf /etc/default/minifirewall
install --mode 0644 minifirewall.service /etc/systemd/system/minifirewall.service
systemctl daemon-reload
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

To use minifirewall with Docker you must to change the variable `DOCKER='on'`
By default, exposed services won't be reachable outside the host.

If you need to allow/deny access to outside hosts, you can rely on the chain `MINIFW-DOCKER-INPUT-MANUAL`
*Note* : this chain is only crossed by incoming 'tcp syn' packets.

Examples : 

~~~
# Open publicly the docker service exposed on port 80
/sbin/iptables -I MINIFW-DOCKER-INPUT-MANUAL -p tcp -m conntrack --ctorigdstport 80 -j RETURN

# Open to 192.0.2.0/24 the docker service exposed on port 22
/sbin/iptables -I MINIFW-DOCKER-INPUT-MANUAL -p tcp -s 192.0.2.0/24 -m conntrack --ctorigdstport 22 -j RETURN

# Block 192.0.2.42 access the docker service exposed on port 22
/sbin/iptables -I MINIFW-DOCKER-INPUT-MANUAL -p tcp -s 192.0.2.42 -m conntrack --ctorigdstport 80 -j DROP
~~~

Also, in `DOCKER='on'`, host services will be reachable to the containers that are connected on the default bridge (docker0).
From the container, you can reach them at *172.17.0.1* (unless docker0 has a different IP).

Ensure that your services listen on either 0.0.0.0 or *172.17.0.1*/*docker0*. 
Keep in mind that some services may require you to allow the containers IP ranges (Postfix, PostgreSQL,...)
For this case, you can allow *172.16.0.0/12*

If you use different docker network bridge, you'll need to add rules for your network. You can use this one

~~~
# Accept all trafic from 172.16.0.0/12 (RFC1918) to reach 172.17.0.1
/sbin/iptables -I INPUT -p tcp --sport 1024:65535 -s 172.16.0.0/12 -d 172.17.0.1 -j ACCEPT
~~~

If you want to have fine-grained rules for controling the communication from containers to the host services, you can set `DOCKER='manual'`. 
This way, no rules allowing communication from containers host services are created.

You can then create your own set of rules.

~~~
# Allow the containers to reach PostgreSQL (5432/tcp) on 172.17.0.1
/sbin/iptables -I INPUT -p tcp --sport 1024:65535 --dport 5432 -s 172.16.0.0/12 -d 172.17.0.1 -j ACCEPT
~~~

## Usage

~~~
systemctl [start,stop,restart] minifirewall
minifirewall safe-restart
~~~

Formerly :
~~~
/etc/init.d/minifirewall [start,stop,restart]
~~~

If you want to add minifirewall in boot sequence, add the start command to `/usr/share/scripts/alert5`.

## License

This is an [Evolix](https://evolix.com) project and is licensed
under the GPLv3, see the [LICENSE](LICENSE) file for details.
