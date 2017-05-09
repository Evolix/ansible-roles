# evocheck

Install and run evocheck ; a script for checking various settings automatically.

## Tasks

The tasks in `main.yml` install the script. This is temporary as evocheck is a package on Debian which is a bit outdated for the moment. For OpenBSD, it should also be packaged, but the work is not done yet.

A separate `exec.yml` file can be imported manually in playbooks or roles to execute the script. Example :

```
- include_role:
    name: evocheck
    tasks_from: exec.yml
```
