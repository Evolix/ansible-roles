# Set custom web-add.conf file
- "templates/evoadmin-web/web-add.{{ inventory_hostname }}.conf.j2"
- "templates/evoadmin-web/web-add.{{ host_group | default('all') }}.conf.j2"
- "templates/evoadmin-web/web-add.conf.j2"
And force it to update:
	evoadmin_add_conf_force: True

# Set custom web-mail.tpl
- "templates/evoadmin-web/web-mail.{{ inventory_hostname }}.tpl.j2"
- "templates/evoadmin-web/web-mail.{{ host_group | default('all') }}.tpl.j2"
- "templates/evoadmin-web/web-mail.tpl.j2"
And force it to update:
	evoadmin_mail_tpl_force: True

# Set custom evoadmin.conf VHost
- "templates/evoadmin-web/evoadmin.{{ inventory_hostname }}.conf.j2"
- "templates/evoadmin-web/evoadmin.{{ host_group | default('all') }}.conf.j2"
- "templates/evoadmin-web/evoadmin.conf.j2"
And force it to update:
	evoadmin_force_vhost: True

# Set custom config.local.php
- "templates/evoadmin-web/config.local.{{ inventory_hostname }}.php.j2"
- "templates/evoadmin-web/config.local.{{ host_group | default('all') }}.php.j2"
- "templates/evoadmin-web/config.local.php.j2"
And force it to update:
	evoadmin_config_local_php_force: True

# Set evoadmin-web sudoers file
- "templates/evoadmin-web/sudoers.{{ inventory_hostname }}.j2"
- "templates/evoadmin-web/sudoers.{{ host_group | default('all') }}.j2"
- "templates/evoadmin-web/sudoers.j2"
- "sudoers.j2"
And force it to update:
	evoadmin_sudoers_conf_force: True

# Set evoadmin-web sudoers file
evoadmin_htpasswd: True

Overwrite its template:
- "templates/evoadmin-web/htpasswd.{{ inventory_hostname }}.j2"
- "templates/evoadmin-web/htpasswd.{{ host_group | default('all') }}.j2"
- "templates/evoadmin-web/htpasswd.j2"
- "htpasswd.j2"
And force it to update:
	evoadmin_htpasswd_force: True
