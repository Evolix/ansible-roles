# newrelic-sources

Installation of NewRelic tools.

## Tasks

Everything is in the `tasks/main.yml` file.

NB : the repository key is store in the role and not fetched online, for performance reasons.

## Variables

* `newrelic_license`: license key (default: empty).
* `newrelic_appname`: application name (default: empty).

* `newrelic_php` : install the php module (default: `False`)
* `newrelic_sysmond` : install the sysmond agent (default: `True`)
