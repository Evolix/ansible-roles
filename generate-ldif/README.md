# generate-ldif

Install generateldif ; a script for building an ldif file, ready to import into LDAP.

## Tasks

The roles install the script, but doesn't run it.

A separate `exec.yml` task file can be played manually in playbooks or roles to execute the script. Example :

```
- include_role:
    name: generate-ldif
    tasks_from: exec.yml
```
## Variables

* `general_scripts_dir` : parent directory for the script
* `client_number` : client number (default: `XXX`)
* `monitoring_mode` : `everytime` or `worktime` (default: `everytime`)
* `monitoring_type` : `icmp` or `nrpe` (default: `icmp`)
* `monitoring_timeout` : timeout for nrpe checks, in seconds (default: `10`)
