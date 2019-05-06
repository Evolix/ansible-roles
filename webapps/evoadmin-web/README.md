# Set custom web-add.conf file
- "templates/evoadmin-web/web-add.{{ inventory_hostname }}.conf.j2"
- "templates/evoadmin-web/web-add.{{ host_group }}.conf.j2"
- "templates/evoadmin-web/web-add.conf.j2"
And force it to update:
	web_add_conf_force: True

# Set custom web-mail.tpl
- "templates/evoadmin-web/web-mail.{{ inventory_hostname }}.tpl.j2"
- "templates/evoadmin-web/web-mail.{{ host_group }}.tpl.j2"
- "templates/evoadmin-web/web-mail.tpl.j2"
And force it to update:
	web_mail_tpl_force: True

# Set custom evoadmin.conf VHost
- "templates/evoadmin-web/evoadmin.{{ inventory_hostname }}.conf.j2"
- "templates/evoadmin-web/evoadmin.{{ host_group }}.conf.j2"
- "templates/evoadmin-web/evoadmin.conf.j2"
And force it to update:
	evoadmin_web_conf_force: True

# Set custom config.local.php
- "templates/evoadmin-web/config.local.{{ inventory_hostname }}.conf.j2"
- "templates/evoadmin-web/config.local.{{ host_group }}.conf.j2"
- "templates/evoadmin-web/config.local.conf.j2"
And force it to update:
	evoadmin_web_config_local_php_force: True

# Set evoadmin-web sudoers file
- "templates/evoadmin-web/sudoers.{{ inventory_hostname }}.j2"
- "templates/evoadmin-web/sudoers.{{ host_group }}.j2"
- "templates/evoadmin-web/sudoers.j2"
- "sudoers.j2"
And force it to update:
	evoadmin_web_sudoers_conf_force: True