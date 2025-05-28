# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project does not follow semantic versioning.
The **major** part of the version is the year
The **minor** part changes is the month
The **patch** part changes is incremented if multiple releases happen the same month

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [25.05] - 2025-05-27

### Changed

* better names for LDAP dumps

### Removed

* remove useless LDAP backup

## [25.04] - 2025-04-10

### Added

* more comments in backup script template

### Changed

* default canary file is in a top-level directory, for sorting purposes

## [25.03] - 2025-03-31

### Changed

* after wc(1), use awk(1) instead of cut(1)

## [25.02.1] - 2025-02-13

### Changed

* improve evobackup template documentation

## [25.02] - 2025-02-12

### Changed

* utilities: replace realpath(1) for OpenBSD (missing options)
* main: use short option for OpenBSD grep(1)

### Removed

* disable mtree on OpenBSD (missing important feature)

## [25.01] - 2025-01-07

### Fixed

* dump_elasticsearch: Add an `\n` before HTTP status code
* Fix compatibility with OpenBSD

### Added

* Add function for backup Linstor Database
* Introducing munin-plugins for bkctld

## [24.12] - 2022-12-18

### Changed

* client: the template defaults to full Evolix backup

### Fixed

* client: add exclude for 'lxc/*/rootfs/dev'

## [24.11] - 2022-11-29

### Fixed

* dump_postgresql_per_base: look for correct variable to build connect options
* dump_postgresql_per_base: return if postgresql directory is missing
* dump_redis: choose all instances if none given
* dump_redis: clean backup directory only if the Redis instance is valid
* dump_redis: do not delete entire backup directory
* dump_redis: use dynamic config for each instance

## [24.07] - 2022-07-16

### Changed

* Allow everybody to "x" on LOCAL_BACKUP_DIR
* dump/mysql.sh : give write permissions to mysql on tabs directories

## [24.05.1] - 2022-05-14

### Fixed

* client: fix shell syntax error

## [24.05] - 2022-05-02

### Added

* evobackupctl: update LIBDIR when copying the template

### Changed

* evobackupctl: simplify the program path retrieval

## [24.04.1] - 2022-04-30

### Fixed

* evobackupctl: quote ARGS variable for options parsing.

## [24.04] - 2022-04-29

### Added

* Vagrant definition for manual tests

### Changed

* split functions into libraries
* add evobackupctl script
* change the "zzz_evobackup" script to a template, easy to copy with evobackupctl
* use env-based shebang for shell scripts
* use $TMPDIR if available

### Removed

* update-evobackup-canary is managed by ansible-roles.git
* deployment by Ansible is managed elsewhere (now in evolix-private.git, later in ansible-roles.git)

### Fixed

* don't exit the whole program if a sync task can't be done

## [22.12] - 2022-12-27

### Changed

* Use --dump-dir instead of --backup-dir to suppress dump-server-state warning
* Do not use rsync compression
* Replace rsync option --verbose by --itemize-changes
* Add canary to zzz_evobackup
* update-evobackup-canary: do not use GNU date, for it to be compatible with OpenBSD
* Add AGPL License and README
* Script now depends on Bash
* tolerate absence of mtr or traceroute
* Only one loop for all Redis instances
* remodel how we build the rsync command
* use sub shells instead of moving around
* Separate Rsync for the canary file if the main Rsync has finished without errors

### Removed

* No more fallback if dump-server-state is missing

### Fixed

* Make start_time and stop_time compatible with OpenBSD

## [22.03] - 2022-04-03

Split client and server parts of the project
