# evobackup-client

Allows the configuration of backups to one or more remote filesystems.

The backup hosts and the ports in use need to be defined in
evobackup-client__hosts before running it.

The default zzz_evobackup.sh configures a system only backup, but the
template can be overriden to configure a full backup instead. If
you change the variables in defaults/main.yml you can easily run
this again and configure backups to a second set of hosts.

Do not forget to set the evobackup-client__mail variable to an
email adress you control.

You can add this example to an installation playbook to create the
ssh key without running the rest of the role.

~~~
  post_tasks:
    - include_role:
        name: evobackup-client tasks_from: ssh_key.yml
~~~
