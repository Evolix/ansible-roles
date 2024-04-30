# evobackup-client

Install the necessary libraries and script to configure backup scripts.

Additional information:

* [evobackup-client documentation](https://gitea.evolix.org/evolix/evobackup/src/branch/master/client/README.md)
* canary

## Available variables

* `evobackup_client__lib_dir` : directory for libraries (default: `/usr/local/lib/evobackup`)
* `evobackup_client__bin_dir` : directory for scripts/binaries (default: `/usr/local/bin`)
* `evobackup_client__update_canary_enable` : should the canary be updated (default: `True`)
* `evobackup_client__update_canary_path` : path for the canary update script (default: `/etc/cron.daily/000-update-evobackup-canary`)
* `evobackup_client__update_canary_who` : who the canary update must be attributed to (default: `@daily`)
