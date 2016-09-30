# apt-upgrade

Upgrades Debian packages

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `apt_upgrade_mode` : kind of upgrade to do (cf. http://docs.ansible.com/ansible/apt_module.html#options)

Choice of upgrade mode can be set in a variables file (ex. `vars/main.yml`) or when invoking the role (`- { role: apt-upgrade, apt_upgrade_mode: safe }`).
