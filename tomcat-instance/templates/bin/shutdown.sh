#!/bin/sh
# alias for compatibility

sudo -iu {{ tomcat_instance_name }} systemctl --user stop tomcat
{% if tomcat_instance_mail is defined %}
/bin/sh -c date | /usr/bin/mail -s "{{ inventory_hostname }}/{{ tomcat_instance_name }} : Shutdown instance" {{ tomcat_instance_mail }}
{% endif %}
