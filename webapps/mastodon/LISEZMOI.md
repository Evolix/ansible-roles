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

- rbenv

Exemple de playbook
-------------------

```
- name: "Déployer un serveur Mastodon"
  hosts: 
    - all
  vars:
    # Supplanter ici les variables du rôle
    mastodon_domains: ['votre-vrai-domaine.org']
    mastodon_instance: 'mon-mastodon'
    mastodon_db_host: 'localhost'
    mastodon_db_user: "{{ mastodon_instance }}"
    mastodon_db_name: "{{ mastodon_instance }}"
    mastodon_db_password: 'zKEh-CHANGEZ-MOI-qIKc'
    mastodon_app_secret_key_base: ""
    mastodon_app_otp_secret: ""
    mastodon_app_vapid_private_key: ""
    mastodon_app_vapid_public_key: ""
    mastodon_app_smtp_from_address: "mastodon@votre-vrai-domaine.org"

  pre_tasks:
    - name: "Installer les rôles systèmes"
      roles:
        - { role: nodejs, nodejs_apt_version: 'node_16.x', nodejs_install_yarn: true }
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
