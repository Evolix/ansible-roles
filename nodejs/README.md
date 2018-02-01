# nodejs

Installation of NodeJS from NPM repositories.

## Tasks

Everything is in the `tasks/main.yml` file.

## Variables

* `nodejs_apt_version`: version for the repository (default: `node_6.x`).

## 1 - Create a playbook with nodejs role

~~~
---
- hosts: hostname
  become: yes
  roles:
    - nodejs
~~~

### 2 - Install nodejs prerequisite with ansible

~~~
# ansible-playbook playbook.yml -K --check --diff --limit hostname
~~~
