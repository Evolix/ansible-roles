# haproxy

Install HAProxy.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `general_package_release`: which Debian release to use generally (default: `stable`).
* `haproxy_package_release`: which Debian release to use for HAProxy (default: `general_package_release`).

The full list of variables (with default values) can be found in `defaults/main.yml`.
