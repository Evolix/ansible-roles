# munin

Installation de Rbenv, Ruby et des gems par défaut.

## Taches

L'ensemble des actions est dans le fichier `tasks/main.yml`

## Variables possibles

Les seules variables sont liées au hostname (court et complet) qui sont simplement déduites des facts.

* `rbenv_version`: version de Rbenv à installer, `v1.0.0` par défaut
* `rbenv_ruby_version`: version de Ruby à installer, `2.3.1` par défaut
* `rbenv_root`: dossier d'installation, `~/.rbenv` par défaut
* `rbenv_repo`: source Git pour Rbenv
* `rbenv_plugins`: liste des plugins Rbenv à installer

Le rôle doit être ajouté en indiquant l'utilisateur concerné :

```
roles:
  - { role: rbenv, username: 'johndoe' }
```
