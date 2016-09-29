# munin

Installation de Redis.

Rôle basé sur https://github.com/geerlingguy/ansible-role-redis

## Taches

L'ensemble des actions est dans le fichier `tasks/main.yml`

## Variables possibles

Les variables principales sont :

* `redis_daemon`: nom du processus
* `redis_conf_path`: emplacement du fichier de config
* `redis_port`: port TCP d'écoute
* `redis_bind_interface`: IP d'écoute
* `redis_unixsocket`: socket Unix écouté
* `redis_loglevel`: verbosité des logs
* `redis_logfile`: emplacement du fichier de log

La liste complète est disponible dans `defaults/main.yml`.
