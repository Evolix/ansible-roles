# Postfix

Install Postfix

## Tasks

Minimal configuration is in `tasks/main.yml` and optional customization in :

* `slow_transport.yml` : slow transport to specific destination.

## Available variables

Main variables are :

* `postfix_hostname` : hostname for Postfix ;
* `postfix_slow_transport` : enable customization for delivrability.

The full list of variables (with default values) can be found in `defaults/main.yml`.
