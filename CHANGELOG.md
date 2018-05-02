# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project does not follow semantic versioning.
The **major** part of the version is aligned with the stable version of Debian.
The **minor** part changes with big changes (probably incompatible).
The **patch** part changes incrementally at each release.

## [Unreleased]

### Added

### Changed

### Fixed
* evolinux-users: secondary groups are comma-separated

### Security

## [9.1.9] - 2018-04-24

### Added

### Changed
* apache: customize logrotate (52 weeks)
* evolinux: groups for SSH configuration are used with Debian 10 and later
* evolinux-base: fail2ban is not enabled by default
* evolinux-users: refactoring of the SSH configuration
* mysql-oracle: copy evolinux config files in mysql.cond.d
* mysql/mysql-oracle: mysqltuner cron scripts is 0755
* generate-ldif: add a minifirewall service when /etc/default/minifirewall exists

## [9.1.8] - 2018-04-16

### Changed
* packweb-apache: use dependencies instead of include_role for apache and php roles

### Fixed
* mysql: use check_mode for apg command (Fix --check)
* mysql/mysql-oracle: properly reload systemd
* packweb-apache: use check_mode for apg command (Fix --check)

## [9.1.7] - 2018-04-06

### Added
* added a few become attributes where missing
* etc-git: add tags for Ansible
* evolinux-base: install ncurses-term package
* haproxy: install Munin plugins
* listupgrade: add service restart notification for Squid and libstdc++6
* minifirewall: add "check_minifirewall" Nagios plugin (and `minifirewall_status` script)
* mysql-oracle: new role to install MySQL 5.7 with Oracle packages
* mysql: remount /usr before creating scripts directory
* nagios-nrpe: add "check_open_files" plugin
* nagios-nrpe: mark plugins as executable
* nodejs: Yarn package manager can be installed (default: `false`)
* packweb-apache: choose mysql variant (default: `debian`)
* postfix: add lines in /etc/.gitignore
* proftpd: use "proftpd_accounts" list to manage ftp accounts
* redmine: added missing tags

### Changed
* elasticsearch: RESTART_ON_UPGRADE is configurable (default: `true`)
* elasticsearch: use ES_TMPDIR variable for custom tmpdir, (from `/etc/default/elasticsearch` instead of changing `/etc/elesticsearch/jvm.options`).
* evolinux-base: Exec the firewall tasks sooner (to avoid dependency issues)
* evolinux-users: split AllowGroups/AllowUsers modes for SSH directives
* mongodb: allow unauthenticated packages for Jessie
* mongodb: configuration is forced by default but it's configurable (default: `false`)
* mongodb: rename logrotate script
* nagios-nrpe: mark plugins as executable
* nginx: don't debug variables in verbosity 0
* nginx: package name can be specified (default: `nginx-full`)
* php: fix FPM custom file permissions
* php: more tasks notify FPM handler to restart if needed
* webapps/evoadmin-web: Fail if variable evoadmin_contact_email isn't defined

### Fixed
* dovecot: fix support of plus sign
* mysql/mysql-oracle: mysqltuner cron task is executable
* nginx: fix basic auth for default vhost
* rbenv: fix become user issue with copy tasks

## [9.1.6] - 2018-02-02

### Added
* mongodb: install python-pymongo for monitoring
* nagios-nrpe: allowed_hosts can be updated

### Changed
* Changelog: explain the versioning scheme
* Changelog: add a release date for 9.1.5
* evoacme: exclude typical certbot directories

### Fixed
* fail2ban: fix horrible typo, Python is not Ruby
* nginx: fix servers status dirname

## [9.1.5] - 2018-01-18

### Added
* There is a changelog!
* redis: configuration variable for protected mode (v3.2+)
* evolinux-users: users are in "adm" group for Debian 9 or later
* evolinx-base: purge locate/mlocate packages
* evolinx-base: create /etc/evolinux if missing
* many Ansible tags for easier fine grained execution of playbooks
* apache/nginx: server status suffix management
* unbound: retrieve list of root DNS servers
* redmine: ability to install themes and plugins

### Changed
* rbenv: Ruby 2.5 becomes the default version
* evocheck: update upstream version embedded in role (c993244)
* bind: keep 52 weeks of logs

### Fixed
* squid: different logrotate file for Jessie or Stretch+
* evoacme: don't invoke evoacme if no vhost is found
* evomaintenance: explicit quotes in config file
* redmine: force xpath gem < 3.0.0

### Security
* evomaintenance: fix permissions for config file

## [9.1.4] - 2017-12-20

### Added
* php: install php5-intl (for Jessie) and php-intl (for Debian 9 or later)
* mysql: add a check_mysql_slave in nrpe configuration
* ldap: slapd tcp port is configurable
* elasticsearch: broader patterns for log rotation

### Changed
* split IP lists in 2 – default and additional – for easier customization.

### Fixed
* minifirewall: allow outgoing SSH connections over IPv6
* nodejs: rename source.list file

### Security
* evoadmin-web: change config.local.php file permissions
* evolinux-base: change default_www file permissions

## [9.1.3] 2017-12-08

### Added
* evolinux-base: install traceroute package
* evolinux-base/ntpd: purge openntpd
* tomcat: add Tomcat 8 cmpatibility
* log2mail: add "The total blob data length" pattern for MySQL
* nagios-nrpe: add bkctld check in evolix.cfg
* varnish: reload or restart if needed
* rabbitmq: add a munin plugin and an NRPE check
* minifirewall: add debug for variables
* elastic: option for stack main version

### Changed
* nginx: rename Let's Encrypt snippet
* nginx: simpler apt preferences for backports
* generate-ldif: add clamd service instead of clamav_db
* mysql: parameterize evolinux config files
* rbenv: use Rbenv 1.1.1 and Ruby 2.4.2 by default
* elasticsearch: update curator debian repository
* evoacme: crontab management
* evoacme: better documentation
* mongodb: comatible with Stretch

### Removed
* mongodb: logfile/pidfile are not configurable on Jessie
* minifirewall: remove zidane.evolix.net from HTTPSITES

### Fixed
* nginx: fix munin CGI graphs
* ntpd: fix default configuration (localhost only)
* logstash: fix permissions on pipeline configuration
* postfix/spamassassin: add user in cron job
* php: php.ini custom file are now readable
* hostname customization needs the dbus package

## [9.1.2] 2017-12-05

### Fixed
* listupgrade: remount /usr as rw

## [9.1.1] 2017-11-21

### Added
* amazon-ec2: add egress rules

### Fixed
* evoacme: fix multiple bugs

## [9.1.0] 2017-11-19

_Warning: huge release, many entries are missing below._

### Added
* amazon-ec2: new role, for EC2 instances creation
* Move /usr rw remount into remount-usr role
* kibana: host and basepath configuration
* kibana: move optimize and data to /var
* logstash: daily job for log rotation
* elasticsearch: daily job for log rotation
* roundcube: add link in default site index
* nagios-nrpe: add opendkim check

### Changed
* Combine evolix and additional trusted IP addresses
* amazon-ec2: split tasks
* apt: don't upgrade by default
* postfix: extract main.cf md5sum into variables
* evolinux-base: cache hwraid pgp key locally
* evoacme: improve cron task
* elasticsearch: use elastic.list APT source list for curator
* ldap: better variables

### Fixed
* fail2ban: create config hierarchy beforehand
* elasticsearch: fix datadir/tmpdir conditions
* elastic: remove double ".list" suffix
* nagios-nrpe: fix check_free_mem for OpenBSD 6.2
* nagios-nrpe: fix check_amavis

### Removed

### Security


## [9.0.1] 2017-10-02

### Added
* haproxy: add a Nagios check
* php: add "sury" mode for PHP 7.1 on Stretch
* minifirewall: explicit dependency on iptables
* apt: remove Gandi source files
* docker-host: new variable for docker home

### Changed
* php: install php5/php package after fpm/libapache2-mod-php

### Fixed
* mysql: add "REPLICATION CLIENT" privilege for nrpe
* evoadmin-web: revert from variables to keywords in the templates
* evoacme: many fixes
* etc-git: detect user if root (without su or sudo)
* docker-host: clean override of docker systemd unit
* varnish: fix systemd unit override

## [9.0.0] 2017-09-19

First official release
