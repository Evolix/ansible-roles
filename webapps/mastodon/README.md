mastodon
=========

This role installs or upgrades the server for Mastodon, a free and decentralized microblogging social network. 

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
- postgresql
- redis
- elasticsearch
- rbenv
- nginx
- certbot

Example Playbook
----------------

```
- name: "Deploy a Mastodon server"
  hosts: 
    - all
  vars:
    # Overwrite the role variable here
    domains: ['your-real-domain.org']
    service: 'my-mastodon'
    db_host: 'localhost'
    db_user: "{{ service }}"
    db_name: "{{ service }}"
    db_password: 'zKEh-CHANGE-ME-qIKc'
    app_secret_key_base: ""
    app_otp_secret: ""
    app_vapid_private_key: ""
    app_vapid_public_key: ""
    app_smtp_from_address: "mastodon@your-real-domain.org"

  pre_tasks:
    - name: "Install system roles"
      roles:
        - { role: nodejs, nodejs_apt_version: 'node_16.x', nodejs_install_yarn: True }
        - { role: postgresql }
        - { role: redis }
        - { role: elasticsearch }
        - { role: nginx }
        - { role: certbot }
  roles:
    - { role: webapps/mastodon , tags: "mastodon" }
```

License
-------

GPLv3

Author Information
------------------

Mathieu Gauthier-Pilote, sys. admin. at Evolix.
