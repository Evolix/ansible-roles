# haproxy

Install HAProxy.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

There is no variable.

## Configuration templates

The roles compiles a `haproxy.cfg` file based on templates that are looked up in that order :
1. `{{ playbook_dir}}/templates/haproxy/haproxy.{{ inventory_hostname}}.cfg.j2`
2. `{{ playbook_dir}}/templates/haproxy/haproxy.{{ host_group}}.cfg.j2` (NB : `host_group` is not a core variable, it must be defined in `group_vars` files.)
3. `{{ playbook_dir}}/templates/haproxy/haproxy.default.cfg.j2`

If nothing is found, the role falls back to the template embedded in the role : `templates/haproxy.default.cfg.j2`
