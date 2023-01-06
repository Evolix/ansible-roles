mastodon
=========

Ce rôle installe le serveur de Mastodon, une application de microblogage, libre et autohébergée. 

Notez qu'hormis le présent fichier LISEZMOI.md, tous les fichiers du rôle mastodon sont rédigés en anglais afin de suivre les conventions de la communauté Ansible, favoriser sa réutilisation et son amélioration, etc. Libre à vous cependant de faire appel à ce role dans un playbook rédigé principalement en français ou toute autre langue.

Requis
------

...

Variables du rôle
-----------------

Plusieurs des valeurs par défaut dans defaults/main.yml doivent être changées soit directement dans defaults/main.yml ou mieux encore en les supplantant ailleurs, par exemple dans votre playbook (voir l'exemple ci-bas).

Dépendances
------------

Ce rôle Ansible dépend des rôles suivants :

- nodejs
- postgresql
- redis
- elasticsearch
- rbenv
- nginx
- certbot

Exemple de playbook
-------------------

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

Licence
-------

GPLv3

Infos sur l'auteur
------------------

Mathieu Gauthier-Pilote, administrateur de systèmes chez Evolix.
