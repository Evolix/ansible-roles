# monit

Installation de Monit et ajout d'une configuration personnalisée.

## Taches

L'ensemble des action est dans le fichier `tasks/main.yml`

## Variables possibles

* `monit_daemon_time` : délai d'exécution des vérifications (en secondes)
* `monit_httpd_enable` : activation du serveur http intégré (`true`/`false`)
* `monit_httpd_port` : port d'écoute pour le serveur http
* `monit_httpd_allow_items` : liste des IP/hosts autorisés à se connecter
