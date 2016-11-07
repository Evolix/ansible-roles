# evolinux-admin-users

Creates admin users accounts, based on a configuration data structure.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

The variable `evolinux_admin_users` must be a "hash" of one or more users :

```
evolinux_admin_users:
  - name: foo
    uid: 1001
    fullname: 'Mr Foo'
    password_hash: 'sdfgsdfgsdfgsdfg'
    ssh_key: 'ssh-rsa AZERTYXYZ'
  - name: bar
    uid: 1002
    fullname: 'Mr Bar'
    password_hash: 'gsdfgsdfgsdfgsdf'
    ssh_key: 'ssh-rsa QWERTYUIOP'
```

* `general_scripts_dir`: general directory for scripts installation (default: `/usr/local/bin`).
* `listupgrade_scripts_dir`: script directory for listupgrade (default: `general_scripts_dir`).
* `evomaintenance_scripts_dir`: script directory for evomaintenance (default: `general_scripts_dir`).
