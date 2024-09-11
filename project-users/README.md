# project-users

Creates users accounts for the current project, based on a configuration data structure.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

### Main data structure

The variable `project_users_db` must be a "dict" of one or more users :

```
project_users_db:
  foo:
    name: foo
    uid: 1001
    fullname: 'Mr Foo'
    password_hash: 'sdfgsdfgsdfgsdfg'
    update_password: always
    groups:
      - adm
      - docker
    ssh_keys:
      - 'ssh-rsa AZERTYXYZ'
  bar:
    name: bar
    uid: 1002
    fullname: 'Mr Bar'
    password_hash: 'gsdfgsdfgsdfgsdf'
    update_password: on_create
    ssh_keys:
      - 'ssh-rsa QWERTYUIOP'
```

Zero or more `groups` can be set per user. It will be added in each each them (and created if necessary).

Zero or more `ssh_keys` can be set. A block with all of them will be added (or removed) in the authorized_keys file.

If set, `update_password` can have 2 possible values ; `on_create` (to set the password only when creating the user) of `always` (to set it each time the task is played).

### Other variables

The list of users that will be added or removed from a server depend on those variables :

* `project_users_absent_for_all`
* `project_users_absent_for_group`
* `project_users_absent_for_host`
* `project_users_present_for_all`
* `project_users_present_for_group`
* `project_users_present_for_host`

`project_users_main_group` is the name of the group where all the users will be. It is usually the name of the project or the client.

Home directories permissions can be change with `project_users_homedir_mode` (default: `0700`).

`project_users_strict_uid` :

* `False` (default) : if the desired UID is already taken when the user is created, a random UID is used ;
* `True` : an error is raised if the desired UID is not available.

`project_users_disable_ssh_password` (default: `False`) adds a `Match Group` block that disables the password authentication for the main project group

If you want to give sudo permissions to those users, you can set `project_users_sudoers_group` with the name of the group (usually the name of the main group with `-sudo` as a suffix). With `project_users_sudoers_template` you can provide the path to a template that will be deployed to `project_users_sudoers_path`.

If a sudo group is defined and a user belongs to this group, its profile will contain a shell trap for evomaintenance (default: `trap \"sudo /usr/share/scripts/evomaintenance.sh\" 0`) which is customizable with `project_evomaintenance_trap_command`.
