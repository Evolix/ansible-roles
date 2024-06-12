etherpad
=========

This role installs or upgrades the server for the real-time collaborative editor Etherpad. 

FRENCH: Voir le fichier LISEZMOI.md pour le français.

Requirements
------------

...

Role Variables
--------------

Several of the default values in defaults/main.yml must be changed either directly in defaults/main.yml or better even by overwriting them somewhere else, for example in your playbook (see the example below).

Dependencies
------------

This Ansible role depends on the following other roles:

- nodejs

Example Playbook
----------------

```
- name: "Deploy an Etherpad server"
  hosts: 
    - all
  vars:
    # Overwrite the role variable here
    service: 'my-etherpad'
    etherpad_domains: ['your-real-domain.org']
    etherpad_db_host: 'localhost'
    etherpad_db_user: "{{ service }}"
    etherpad_db_name: "{{ service }}"
    etherpad_db_password: 'zKEh-CHANGE-ME-qIKc'

  pre_tasks:
    - name: "Install system roles"
      roles:
        - { role: nodejs, nodejs_apt_version: "{{ etherpad_node_version }}" }

  roles:
    - { role: webapps/etherpad , tags: "etherpad" }
```

License
-------

GPLv3

Author Information
------------------

Mathieu Gauthier-Pilote, sys. admin. at Evolix.
