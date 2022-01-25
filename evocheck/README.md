# evocheck

Install and run evocheck ; a script for checking various settings automatically.

## Tasks

The roles does not install evocheck by default as it should be installed through dependencies.

A separate `exec.yml` file can be imported manually in playbooks or roles to execute the script. Example :

```
- include_role:
    name: evolix/evocheck
    tasks_from: exec.yml
```
## Variables

We can force install via :
* `evocheck_update_crontab` : will update the crontab (default: `True`)
