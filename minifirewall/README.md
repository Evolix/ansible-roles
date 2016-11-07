# minifirewall

Install minifirewall a simple and versatile local firewall.

The firewall is not started by default, but an init script is installed.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `minifirewall_int`: which network interface to protect (default: detected default ipv4 interface)
* `minifirewall_ipv6_enabled`: (default: `on`)
* `minifirewall_int_lan`: (default: IP/32)
* `minifirewall_trusted_ips`: with IP/hosts should be trusted for full access (default: none)
* `minifirewall_privilegied_ips`: with IP/hosts should be trusted for restricted access (default: none)

Some IP/hosts must be configured or the server will be inaccessible via network.
