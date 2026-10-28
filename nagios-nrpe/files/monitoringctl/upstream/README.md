<!--
SPDX-FileCopyrightText: 2024 Evolix

SPDX-License-Identifier: GPL-3.0-or-later
-->

# monitoringctl

**`monitoringctl` gives some control over NRPE checks and alerts.**

* Depends: bash-completion, nagios-nrpe-plugin, gawk
* Supports: Python >= 3.4 (Debian >= 8)

Its main features are to verify the checks status, and to disable (e.g. downtime) checks *locally* on the remote side for a certain duration.


## Howto

### Install monitoringctl

Use [nagios-nrpe](https://forge.evolix.net/evolix/ansible-roles/src/branch/stable/nagios-nrpe) role from `evolix/ansible-roles`.


### Configure NRPE

Firs, allow `nagios` user to re-enable checks:

~~~bash
nagios ALL = NOPASSWD:/usr/local/bin/monitoringctl enable *
~~~

Then, in NRPE configuration, prefix all NRPE check commands with `alerts_wrapper --name CHECK_NAME --`.

For instance, if `alerts_wrapper.py` is installed as `/usr/local/lib/monitoringctl/alerts_wrapper`:

~~~bash
command[check_load]=/usr/local/lib/monitoringctl/alerts_wrapper --name load -- CHECK_LOAD_COMMAND
~~~


### Use monitoringctl

Note: `monitoringctl` must be run as root.

~~~bash
# monitoringctl show load
Command used by NRPE:
    /usr/local/lib/monitoringctl/alerts_wrapper --name load -- /usr/lib/nagios/plugins/check_load --percpu --warning=0.7,0.6,0.5 --critical=0.9,0.8,0.7

Command without 'alerts_wrapper':
    /usr/lib/nagios/plugins/check_load --percpu --warning=0.7,0.6,0.5 --critical=0.9,0.8,0.7
~~~

~~~bash
# monitoringctl status load
Check  Status   Re-enable time  Disable message
-----  ------   --------------  ---------------
load   Enabled
~~~

~~~bash
# monitoringctl check load
Command played by NRPE:
    /usr/local/lib/monitoringctl/alerts_wrapper --name load -- /usr/lib/nagios/plugins/check_load --percpu --warning=0.7,0.6,0.5 --critical=0.9,0.8,0.7
Command without 'alerts_wrapper':
    /usr/lib/nagios/plugins/check_load --percpu --warning=0.7,0.6,0.5 --critical=0.9,0.8,0.7

NRPE service output (on 127.0.0.1:5666):

OK - load average: 0.18, 0.17, 0.16
load1=0.180;0.700;0.900;0; load5=0.170;0.600;0.800;0; load15=0.160;0.500;0.700;0;

# monitoringctl check
Check                Status   Output (truncated)
-----                ------   ------------------
disk1                OK       DISK OK
dns                  OK       DNS OK: 0.011 seconds response time. evolix.net returns 31.170.8.43 [...]
domains              Warning  WARNING - 0 UNK / 0 CRIT / 3 WARN / 5 OK 
load                 OK       ALERT DISABLED until 24 Dec 2024 at 12:53:20 (54m22s left)
[…]
~~~

~~~bash
# monitoringctl disable load --during 1h10 --message 'Demo'
┌─────────────────────────────────────┐
│Check load will be disabled for 1h10.│
└─────────────────────────────────────┘

Additional information:
* Alerts history is kept in our monitoring system.
* To see when the will be re-enabled, execute 'monitoringctl status load'.
* To re-enable alert(s) before 1h10, execute as root or with sudo: 'monitoringctl enable load'.

> Confirm (y/N)? y
Check load alerts are now disabled for 1h10.
~~~

~~~bash
# monitoringctl enable load --message 'Demo'
Check load alerts are now enabled.
~~~


See `monitoringctl help` for more details.


### Update monitoringctl

Use [nagios-nrpe](https://forge.evolix.net/evolix/ansible-roles/src/branch/stable/nagios-nrpe) role from `evolix/ansible-roles`.



### Playbook example

`install-update-monitoringctl.yml`:

~~~
- hosts: all
  gather_facts: yes
  become: yes

  pre_tasks:
    - include_role:
        name: etc-git
        tasks_from: commit.yml
      vars:
        commit_message: "Ansible pre-run install-update-monitoringctl.yml"

  tasks:
    - include_role:
        name: nagios-nrpe
        tasks_from: monitoringctl.yml

  post_tasks:
    - include_role:
        name: etc-git
        tasks_from: commit.yml
      vars:
        commit_message: "Ansible install-update-monitoringctl.yml"
~~~


### Package monitoringctl in .deb

TODO


