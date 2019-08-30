# evobackup-client

Allows the configuration of backups to a pair of bkctld(8) hosts.

The backup hosts in use need to be defined in evobackup-client___hosts
and the bkctld jail ssh port has to be defined in
evobackup-client___ssh_port before running it.

The default zzz_evobackup.sh configures a system backup, but the
template can be overriden to configure a full backup instead. If
you change the variables in defaults/main.yml you can easily run
this again and configure backups to a second set of bkctld(8) hosts.

Do not forget to set the evobackup-client___mail variable to an
email adress you control.

You can add this example to an installation playbook to create the
ssh key without running the rest of the role.

~~~
  post_tasks:
    - include_role:
        name: evobackup-client tasks_from: ssh_key.yml
~~~
