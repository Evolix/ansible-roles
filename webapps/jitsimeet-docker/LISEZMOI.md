jitsimeet-docker
=====

Ce rôle installe un serveur jitsimeet via docker-compose. 

Notez qu'hormis le présent fichier LISEZMOI.md, tous les fichiers du rôle jitsimeet-docker sont rédigés en anglais afin de suivre les conventions de la communauté Ansible, favoriser sa réutilisation et son amélioration, etc. Libre à vous cependant de faire appel à ce role dans un playbook rédigé principalement en français ou toute autre langue.

Requis
------

...

Variables du rôle
-----------------

Plusieurs des valeurs par défaut dans defaults/main.yml doivent être changées soit directement dans defaults/main.yml ou mieux encore en les supplantant ailleurs, par exemple dans votre playbook (voir l'exemple ci-bas).

Dépendances
------------

...

Exemple de playbook
-------------------

```
- name: "Déployer un serveur jitsimeet (via docker-compose)"
  hosts: 
    - all
  vars:
    # Supplanter ici les variables du rôle
    domains: ['votre-vrai-domaine.org']
    service: 'mon-jitsimeet'

  roles:
    - { role: webapps/jitsimeet-docker , tags: "jitsimeet-docker" }
```

Licence
-------

GPLv3

Infos sur l'auteur
------------------

Mathieu Gauthier-Pilote, administrateur de systèmes chez Evolix.
