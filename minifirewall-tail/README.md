# minifirewall-tail

Compiles a `minifirewall.tail` file based on templates and source it at the end of minifirewall configuration.

Templates are looked up in that order :
1. `{{ playbook_dir}}/templates/minifirewall-tail/{{ inventory_hostname}}`
2. `{{ playbook_dir}}/templates/minifirewall-tail/{{ host_group}}` (NB : `host_group` is not a core variable, it must be defined in `group_vars` files.)
3. `{{ playbook_dir}}/templates/minifirewall-tail/default`

If nothing is found, the role falls back to the temlate embedded in the role : `templates/default`
