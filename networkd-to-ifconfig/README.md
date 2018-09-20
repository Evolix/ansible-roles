# networkd-to-ifconfig

Switch back from systemd "networkd" to plain old /etc/network/interfaces.

The role does nothing if an /etc/network/interfaces file is present.

You should always double-check if everything seems OK, then reboot.

Caveat: a public IPv4 and a public IPv6 are expected.
