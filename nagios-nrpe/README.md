# nagios-nrpe

Installation and custom configuration of Nagios NRPE server.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `nagios_nrpe_allowed_hosts` : list of IP/hosts authorized (default: none).
* `nagios_nrpe_force_update_allowed_hosts` : force update list of allowed hosts (default: `False`)

The full list of variables (with default values) can be found in `defaults/main.yml`.

## Available tags

* `nagios-nrpe` : install Nagios and plugins (idempotent)
* `nagios-plugins` : install only plugins (idempotent)

