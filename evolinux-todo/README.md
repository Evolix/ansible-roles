# evocheck

Creates an /etc/evolinux/todo.txt file to hold information about things to do, gathered by humans or other Ansible tasks

## Tasks

The main tasks install the default file if missing.

A separate `cat.yml` file can be imported manually in playbooks or roles to get the content of the file. Example :

```
- include_role:
    name: evolinux-todo
    tasks_from: cat.yml
```
