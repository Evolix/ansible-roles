etherpad
=========

Ce rôle installe le serveur d'Etherpad, une application rédaction collaborative en temps-réel. 

Notez qu'hormis le présent fichier LISEZMOI.md, tous les fichiers du rôle etherpad sont rédigés en anglais afin de suivre les conventions de la communauté Ansible, favoriser sa réutilisation et son amélioration, etc. Libre à vous cependant de faire appel à ce role dans un playbook rédigé principalement en français ou toute autre langue.

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

Exemple de playbook
-------------------

```
- name: "Déployer un serveur Etherpad"
  hosts: 
    - all
  vars:
    # Supplanter ici les variables du rôle
    etherpad_instance: 'mon-etherpad'
    etherpad_domains: ['votre-vrai-domaine.org']
    etherpad_db_host: 'localhost'
    etherpad_db_user: "{{ etherpad_instance }}"
    etherpad_db_name: "{{ etherpad_instance }}"
    etherpad_db_password: 'zKEh-CHANGEZ-MOI-qIKc'

  pre_tasks:
    - name: "Installer les rôles systèmes"
      roles:
        - { role: nodejs, nodejs_apt_version: "{{ etherpad_node_version }}" }

  roles:
    - { role: webapps/etherpad , tags: "etherpad" }
```

Licence
-------

GPLv3

Infos sur l'auteur
------------------

Mathieu Gauthier-Pilote, administrateur de systèmes chez Evolix.
