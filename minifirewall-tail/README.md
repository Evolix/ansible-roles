# minifirewall-tail

Compiles a `minifirewall.tail` file based on templates and source it at the end of minifirewall configuration.

Templates are looked up in that order :
1. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.{{ inventory_hostname}}.tail.j2`
2. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.{{ host_group}}.tail.j2` (NB : `host_group` is not a core variable, it must be defined in `group_vars` files.)
3. `{{ playbook_dir}}/templates/minifirewall-tail/minifirewall.default.tail.j2`

If nothing is found, the role falls back to the template embedded in the role : `templates/minifirewall.default.tail.j2`
