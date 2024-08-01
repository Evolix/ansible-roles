The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project **does not adhere to [Semantic Versioning](http://semver.org/spec/v2.0.0.html)**.

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [24.08] - 2024-08-01

### Added

* Add contrib/post-release.sh to help with post-release tasks

### Fixed

* Define $USER before it is used

## [24.05] - 2024-05-15

### Added

* Add missing (but documented) `--(no-)evocheck` options

## [23.10.1] - 2023-10-09

### Fixed

* Use a special variable name since USER is always defined from the environment

## [23.10] - 2023-10-09

### Added

* Force a user name with `-u,--user` option (default is still `logname(1)`).
* More people credited

### Deprecated

* `--autosysadmin` is replaced by `--user autosysadmin`



## [22.07] - 2022-07-05

### Added

* Add `--autosysadmin` flag
* Commit change in /etc of lxc containers

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [22.01] - 2022-01-25

### Added

* version/host/user headers in sent email

### Changed

New version pattern

## [0.6.4] - 2021-06-17

### Added

* fallback if findmnt is absent

## [0.6.3] - 2020-02-02

### Added

* Notify syslog when partitions are re-mounted (Linux)

## [0.6.2] - 2020-02-02

### Fixed

* better detection of read-only partitions (Linux)

## [0.6.0] - 2019-11-05

### Added

* commit changes in /usr/share/scripts/ if needed

## Previous changelog

* 0.5.0 : options et mode interactif pour l'exécution des actions, meilleure compatibilité POSIX
* 0.4.1 : Utilisation de "printf" à la place de "echo" pour mieux gérer les sauts de ligne
* 0.4.0 : Amélioration de la récupération d'information (plus de cas gérés). Infos Git avant la saisie.
* 0.3.0 : Écriture dans un fichier de log, amélioration de la récupération d'informations, amélioration de la syntaxe shell
* 0.2.7 : Correction d'un bug lors de l'utilisation de '&' dans le texte
* 0.2.6 : Precision du charset dans les entetes du mail
* 0.2.5 : Correction d'un bug avec le path de sendmail sous OpenBSD
* 0.2.4 : Correction d'un bug lors de l'utilisation de '/' dans le texte
* 0.2.3 : Correction d'un bug avec $REALM
