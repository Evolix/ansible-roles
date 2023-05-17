jitsimeet
=====

This role installs or upgrades the server for jitsimeet. 

FRENCH: Voir le fichier LISEZMOI.md pour le français.

Requirements
------------

...

Role Variables
--------------

Several of the default values in defaults/main.yml must be changed either directly in defaults/main.yml or better even by overwriting them somewhere else, for example in your playbook (see the example below).

Dependencies
------------

...

Example Playbook
----------------

```
- name: "Deploy a jitsimeet server"
  hosts: 
    - all
  vars:
    # Overwrite the role variables here
    domains: ['your-real-domain.org']
    service: 'my-jitsimeet'

  roles:
    - { role: webapps/jitsimeet , tags: "jitsimeet" }
```

License
-------

GPLv3

Author Information
------------------

Mathieu Gauthier-Pilote, sys. admin. at Evolix.
