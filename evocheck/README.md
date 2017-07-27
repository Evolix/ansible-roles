# evocheck

Install and run evocheck ; a script for checking various settings automatically.

## Tasks

The roles does not install evocheck by default as it should be installed through dependencies.
For OpenBSD, it should be packaged, but the work is not done yet.

A separate `exec.yml` file can be imported manually in playbooks or roles to execute the script. Example :

```
- include_role:
    name: evocheck
    tasks_from: exec.yml
```
## Variables

We can force install via :
* `evocheck_force_install: local` : will copy the script provided by the role
* `evocheck_force_install: package` : will install the package via repositories
