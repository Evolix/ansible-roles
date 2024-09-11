mattermost
=====

This role installs or upgrades the server for mattermost. 

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
- name: "Deploy a mattermost server"
  hosts: 
    - all
  vars:
    # Overwrite the role variables here
    domains: ['your-real-domain.org']
    mattermost_instance: 'my-mattermost'

  roles:
    - { role: webapps/mattermost , tags: "mattermost" }
```

License
-------

GPLv3

Author Information
------------------

Mathieu Gauthier-Pilote, sys. admin. at Evolix.
