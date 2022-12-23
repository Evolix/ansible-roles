Role Name
=========

Ce rôle installe le serveur de Mastodon, une application libre de microblogage, libre et autohébergée. 

Requirements
------------

...

Role Variables
--------------

Plusieurs des valeurs par défaut dans defaults/main.yml doivent être changées soit directement dans defaults/main.yml ou mieux encore en les supplantant ailleurs, par exemple dans votre playbook (voir l'exemple ci-bas).

Dependencies
------------

Ce rôle Ansible dépend des rôles suivants :

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
- name: "Déployer un serveur Mastodon"
  hosts: 
    - all
  vars:
    # Supplanter ici les variables du rôle
    domains: ['votre-vrai-domaine.org']
    service: 'mon-mastodon'
    db_host: 'localhost'
    db_user: "{{ service }}"
    db_name: "{{ service }}"
    db_password: 'zKEh-CHANGEZ-MOI-qIKc'
    app_secret_key_base: ""
    app_otp_secret: ""
    app_vapid_private_key: ""
    app_vapid_public_key: ""
    app_smtp_from_address: "mastodon@votre-vrai-domaine.org"

  pre_tasks:
    - name: "Installer les rôles systèmes"
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

BSD

Author Information
------------------

Mathieu Gauthier-Pilote, administrateur de systèmes chez Evolix.
