# minifirewall

Installation of minifirewall a simple and versatile local firewall.

The firewall is not started by default, but an init script is installed.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `minifirewall_int`: which network interface to protect (default: detected default ipv4 interface)
* `minifirewall_ipv6_enabled`: (default: `on`)
* `minifirewall_int_lan`: (default: IP/32)
* `minifirewall_trusted_ips`: with IP/hosts should be trusted for full access (default: none)
* `minifirewall_privilegied_ips`: with IP/hosts should be trusted for restricted access (default: none)
* `minifirewall_tail_included` : source a "tail" file at the end of the main config file. (default: `False`)
* `minifirewall_restart_if_needed` : should the restart handler be executed (default: `True`)
The full list of variables (with default values) can be found in `defaults/main.yml`.

**Some IP/hosts must be configured or the server will be inaccessible via network.**

## minifirewall-tail

Compiles a `minifirewall.tail` file based on templates and source it at the end of minifirewall configuration.

Templates are looked up in that order :
1. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.{{ inventory_hostname}}.tail.j2`
2. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.{{ host_group}}.tail.j2` (NB : `host_group` is not a core variable, it must be defined in `group_vars` files.)
3. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.default.tail.j2`

If nothing is found, the role falls back to the template embedded in the role : `templates/minifirewall.default.tail.j2`
