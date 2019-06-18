# lxc-php

Create LXC containers and install all the required PHP packages as a way to use multiple PHP version on Debian.

*note : this role depend on the lxc role.*

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

As this role depend on the lxc role, please refer to it for a variable exhaustive list.

Here is the list of available variables for the PHP part:

* `php_conf_short_open_tag` Default: `"Off"`
* `php_conf_expose_php` Default: `"Off"`
* `php_conf_display_errors` Default: `"Off"`
* `php_conf_log_errors` Default: `"On"`
* `php_conf_html_errors` Default: `"Off"`
* `php_conf_allow_url_fopen` Default: `"Off"`
* `php_conf_disable_functions` Default: `"exec,shell-exec,system,passthru,putenv,popen"`
