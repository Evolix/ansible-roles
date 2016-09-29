# mysql

Installation de MySQL, une configuration type Evolix et quelques outils.

## Taches

Les taches sont éclatées dans différents fichiers, inclus dans `tasks/main.yml` :

* `packages.yml` : installation des paquets
* `users.yml` : remplacement de l'utilisateur `root` par `mysqladmin`
* `config.yml` : copie des configurations
* `datadir.yml` : configuration du dossier de travail
* `tmpdir.yml` : configuration du dossier temporaire
* `nrpe.yml` : utilisateur `nrpe` pour checks Nagios
* `munin.yml` : activation des plugins Munin
* `log2mail.yml` : recettes log2mail
* `utils.yml` : installation d'outils utiles

## Variables possibles

Les seules variables sont liées au hostname (court et complet) qui sont simplement déduites des facts.

* `mysql_replace_root_with_mysqladmin`: remplacement de `root` par `mysqladmin` – `true` par défaut
* `mysql_thread_cache_size`: nombre de threads pour le cache – nombre de vCPU par défaut
* `mysql_innodb_buffer_pool_size`: taille du buffer InnoDB – 30% de la RAM installée par défaut
* `mysql_custom_datadir`: le dossier de travail personnalisé
* `mysql_custom_tmpdir`: le dossier temporaire personnalisé

NB : le changement de _datadir_ peut se faire plusieurs fois, tant qu'on ne revient pas vers la valeur par défaut (car une fois déplacé un lien symbolique est créé au point de départ).
