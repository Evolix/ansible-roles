# haproxy

Install HAProxy.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `haproxy_backports` : We can either prefer v1.7 from backports for Debian Jessie or v1.8 for Debian Stretch (default: `False`)

## Configuration templates

The roles compiles a `haproxy.cfg` file based on the template set by the
variable `haproxy_config_template`. To override the default file `haproxy/templates/haproxy.role-default.cfg.j2`, your file need to be have a filename other than `haproxy.role-default.cfg.j2`.

For example set `haproxy_config_template` to `"haproxy.cfg.j2"`, and put
that file in ``{{ playbook_dir}}/templates/haproxy.cfg.j2`. Another pattern
could be to set `haproxy_config_template` to `"haproxy/lb.cfg.j2"`, and put
that file in ``{{ playbook_dir}}/templates/haproxy/lb.cfg.j2`.
