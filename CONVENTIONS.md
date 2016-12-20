# Conventions

## Roles

We can use the `ansible-galaxy init` command to bootstrap a new role :

    $ ansible-galaxy init foo
    - foo was created successfully
    $ tree foo
    foo
    ├── defaults
    │   └── main.yml
    ├── files
    ├── handlers
    │   └── main.yml
    ├── meta
    │   └── main.yml
    ├── README.md
    ├── tasks
    │   └── main.yml
    ├── templates
    ├── tests
    │   ├── inventory
    │   └── test.yml
    └── vars
        └── main.yml

All `main.yml` file will be picked up by Ansible automatically, with respect to their own responsibility.

The main directory is `tasks`. It will contains tasks, either all in the `main.yml` file, or grouped in files that can be included in the main file.

`defaults/main.yml` is the place to put the list of all variables for the role with a default value.

`vars` will hold files with variables definitions. Those differ from the defaults because of a much higher precedence (see below).

`files` is the directory where we'll put files to copy on hosts. They will be copied "as-is". When a role has multiple logical groups of tasks, it's best to create a sub-directroy for each group that needs files. The name of files in these directories doesn't have to be the same as the destination name. Example :

    copy:
      src: apt/jessie_backports_preferences
      dest: /etc/apt/apt.conf.d/backports

`templates` is the twin brother of `files`, but differs in that it contains files that can be pre-processed by the Jinja2 templating language. It can contain variables that will be extrapolated before copying the file to its destination.

`handlers` is the place to put special tasks that can be triggered by the `notify` argument of modules. For example an `nginx -s reload` command.

`meta/main.yml` contains … well … "meta" information. There we can define role dependencies, but also some "galaxy" information like the desired Ansible version, supported OS and distributions, a description, author/ownership, license…

`tests` and `.travis.yml` are here to help testing with a test matrix, a test inventory and a test playbook.

We can delete parts we don't need.

### How much goes into a role

We create roles (instead of a plain tasks files) when it makes sense as a whole, and it is more that a series of tasks. It often has variables, files/templates, handlers…

## Syntax

### Pure YAML

It's possible to use a compact (Ansible specific) syntax,

    - name: Add evomaintenance trap for '{{ user.name }}'
      lineinfile: state=present dest='/home/{{ user.name }}/.profile' insertafter=EOF line='trap "sudo /usr/share/scripts/evomaintenance.sh" 0'
      when: evomaintenance_script.stat.exists

but we prefer the pure-YAML syntax

    - name: Add evomaintenance trap for '{{ user.name }}'
      lineinfile:
        state: present
        dest: '/home/{{ user.name }}/.profile'
        insertafter: EOF
        line: 'trap "sudo /usr/share/scripts/evomaintenance.sh" 0'
      when: evomaintenance_script.stat.exists

Here are some reasons :

* when lines get long, it's easier to read ;
* it's a pure YAML syntax, so there is no Ansible-specific preprocessing
* … which means that IDE can show the proper syntax highlighting ;
* each argument stands on its own.

## Variables

### defaults

When a role is using variables, they must be defined (for example in the `defaults/main.yml`) with a default value (possibly Ǹull). That way, there will never be a "foo is undefined" situation.

### progressive specificity

In many roles, we use a *progressive specificity* pattern for some variables.
The most common is for "alert_email" ; we want to have a default email address where all alerts or messages will be sent, but it can be customized globally, and also customized per task/role.

For the *evolinux-base* role we have those defaults :

    general_alert_email: "root@localhost"
    reboot_alert_email: Null
    log2mail_alert_email: Null
    raid_alert_email: Null

In the *log2mail* template, we set the email address like this :

    mailto = {{ log2mail_alert_email or general_alert_email | mandatory }}

If nothing is customized, the mail will be sent to root@localhost, if general_alert_email is changed, it will be used, but if log2mail_alert_email is set to a non-null value, it will have precedence.

## precedence

There are multiple places where we can define variables and there is a specific precedence order for the resolution. Here is [the (ascending) order](http://docs.ansible.com/ansible/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable) :

* role defaults
* inventory vars
* inventory group_vars
* inventory host_vars
* playbook group_vars
* playbook host_vars
* host facts
* play vars
* play vars_prompt
* play vars_files
* registered vars
* set_facts
* role and include vars
* block vars (only for tasks in block)
* task vars (only for the task)
* extra vars (always win precedence)

## Configuration patterns

### lineinfile vs. blockinfile vs. copy/template

When possible, we prefer using the [lineinfile](http://docs.ansible.com/ansible/lineinfile_module.html) module to make very specific changes.
If a `regexp` argument is specified, every line that matches the pattern will be updated. It's a good way to comment/uncomment variable, or add a piece inside a line.

When it's not possible (multi-line changes, for example), we can use the [blockinfile](http://docs.ansible.com/ansible/blockinfile_module.html) module. It manages blocks of text with begin/end markers. The marker can be customized, mostly to use the proper comment syntax, but also to prevent collisions within a file.

If none of the previous can be used, we can use [copy](http://docs.ansible.com/ansible/copy_module.html) or [template](http://docs.ansible.com/ansible/template_module.html) modules to copy an entire file.

### defaults and custom files

We try not to alter configuration files managed by packages. It makes upgrading easier, so when a piece of software has a "foo.d" configuration directory, we add custom files there.

We usually put a `z-evolinux-defaults` with our core configuration. This file can be changed later via Ansible and must not be edited by hand. Example :

    copy:
      src: evolinux-defaults.cnf
      dest: /etc/mysql/conf.d/z-evolinux-defaults.cnf
      force: yes


We also create a blank `zzz-evolinux-custom` file, with commented examples, to allow custom configuration that will never be reverted by Ansible. Example :

    copy:
      src: evolinux-custom.cnf
      dest: /etc/mysql/conf.d/zzz-evolinux-custom.cnf
      force: no

The source file or template shouldn't to be prefixed for ordering (eg. `z-` or `zzz-`). It's the task's responsibility to choose how destination files must be ordered.
