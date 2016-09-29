# apt-upgrade

Mise à jour des paquets APT.

## Taches

L'ensemble des actions est dans le fichier `tasks/main.yml`

## Variables possibles

* `apt_upgrade_mode` : indique le type de mise à jour, `safe` par défaut (cf. http://docs.ansible.com/ansible/apt_module.html#options)

Le choix peut se faire dans un fichier de variables (par exemple `vars/main.yml`) ou bien lors de l'appel du rôle (`- { role: apt-upgrade, apt_upgrade_mode: safe }`)
