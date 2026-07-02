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

### Fixed

### Removed

### Security

## [26.06] 2026-06-15

### Changed

* restart_tomcat_viaxoft: running_custom pour le tomcat de Viaxoft

### Fixed

* repair_disk: support both output from check_disk

## [25.05] 2025-05-28

### Added

* common.sh: Reference Debian 15 "Duke"

### Changed

* common.sh: use evolibs-shell (os-release and calendar) instead of locally implemented functions

## [24.11] 2024-11-08

### Changed

* common.sh: fix Evolix email address for sending email with sendmail

## [24.09.1] 2024-09-17

### Changed

* common.sh: use procfs and readlink to tell if systemd is active or not

## [24.09] 2024-09-17

### Added

* Add repair_amavis
* Add is_systemd() common function

### Changed

* restart_nrpe: auto-detect systemd/sysvinit

## [24.06] 2024-06-17

### Added

* Add `--no-messages` to prevent grep from whining because of missing files

### Changed

* Replace some short options with long options
* Too soon delay moved from 30 min to 15 min (minimum delay during on-call duty period is 22 mins)
* repair_http: restart apache/nginx/php-fpm even if already running

## [24.03.2] 2024-03-19

### Fixed

* log LXC container "restart" as actions to be displayed in notifications.

## [24.03.1] 2024-03-05

### Changed

* post-release.sh: copy restart_nrpe to ansible-roles.git instead of evolix-private.git

### Fixed

* use evolix.net domain instead of evolix.fr

## [24.03] 2024-03-01

### Changed

* common.sh: set permissions on /var/log/autosysadmin
* rename /usr/share/scripts/autosysadmin/{auto,restart}

### Fixed

* show users in the detailed information section of reports

### Removed

* Remove repair_amavis

## [24.02.3] 2024-02-28

### Added

* post-release.sh: script to help copying to downstream repositories

### Removed

* move roles and playbooks to the appropriate external projects



## [24.02.2] 2024-02-27

### Added

* Add script to delete old logs

### Changed

* restart_nrpe: running during non-working hours (FR) by default

## [24.02.1] 2024-02-27

### Added

* Add /usr/local/sbin to cron PATH
* autosysadmin.sh: configurable timeout for check_nrpe (default: 300)
* deploy.restart_nrpe.yml: variable to customize the RUNNING value
* restart: define PATH in crontab

### Changed

* common: don't log OS detection
* common: is_debug() and detect_os() can be executed outside/before initialize()
* common: log when sending mail
* restart: check if supposed to run before initialize the run
* restart: quit silently if not supposed to run

## [24.02] 2024-02-26

### Added

* initialize a CHANGELOG file
* functions: add `set -u` to warn when using unassigned variable
* introduce `PROGNAME` variable
* functions: introduce `LOCK_TIME` variable
* detect bookworm and trixie Debian versions
* repair: introduce `pre_repair()` and `post_repair()` + libraries directory configuration
* restart: introduce `pre_restart()` and `post_restart()` + libraries directory configuration
* lock name is configurable for scripts that need to use the same lock
* Interactive mode
* Preliminary work for PHP 8.3
* Add a global "circuit breaker" (`repair_all='off'`) to disable all repair scripts via configuration
* Add `is_debian_version`` to compare version numbers
* Add support for Debian 7-8 for repair_mysql


### Changed

* Call `evomaintenance --user autosysadmin` instead of `AUTOSYSADMIN=1 evomaintenance`
* Improve NRPE config parsing for command to run (Issue #61)
* Reorganize/clean Vagrant files
* Reorganize ansible and repair/restart files
* Split "functions" library in separate "common", "repair" and "restart" libraries
* Simplify autosysadmin.sh list of cases
* repair: refactor actions for PHP in LXC containers
* Improve Ansible deployment (cron job…)
* Automatic composition of repair list for sudo, NRPE and autosysadmin itself
* Apply shell syntax conventions
* Clean "lastrun" file logic and naming
* Rename is_too_soon → ensure_not_too_soon_or_exit
* Bypass is_supposed_to_run in debug mode

### Fixed

* assign `INTERNAL_LOG` variable

### Removed

* Remove weird characters
* Remove .sh extension for repair scripts (big simplification)
* Remove is_active_user() (unused) and extract useful functions
* Remove old repair scripts when installing
