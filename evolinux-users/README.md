# evolinux-users

Creates evolinux users accounts, based on a configuration data structure.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

The variable `evolinux_users` must be a "dict" of one or more users :

```
evolinux_users:
  foo:
    name: foo
    uid: 1001
    fullname: 'Mr Foo'
    groups: "baz"
    password_hash: 'sdfgsdfgsdfgsdfg'
    ssh_key: 'ssh-rsa AZERTYXYZ'
    create: always
  bar:
    name: bar
    uid: 1002
    fullname: 'Mr Bar'
    groups:
    - "baz"
    - "qux"
    password_hash: 'gsdfgsdfgsdfgsdf'
    ssh_keys:
      - 'ssh-rsa QWERTYUIOP'
      - 'ssh-ed25519 QWERTYUIOP'
    create: on_demand
```

* `evolinux_sudo_group`: which group to use for sudo (default: `evolinux-sudo`)
* `evolinux_ssh_group`: which group to use for ssh (default: `evolinux-ssh`)
* `evolinux_internal_group`: which group to use for all created users (eg. the company name)
* `evolinux_root_disable_ssh`: disable root's ssh access (default: `True`)
