# Dovecot

Installation and basic configuration of dovecot

Do not use this role to update Dovecot 2.2 to 2.3.

## Tasks

Minimal configuration is in `tasks/main.yml`

## Available variables

The full list of variables (with default values) can be found in `defaults/main.yml`.

## Munin plugins

### dovecot_stats_

Note : This is an Evolix patched version.

This plugin can be installed only when installin a server, because it needs Dovevcot plugin stats (Dovecot 2.2) or old_stats (Dovecot 2.3), which previously were not activated by default.

To skip this plugin installation, use "--skip-tags dovecot_stats_".

