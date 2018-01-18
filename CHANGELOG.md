# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project does not follow semantic versioning.
The major part of the version is aligned with the stable version of Debian.
The minor part changes with big changes (probably incompatible).
The patch part changes incrmentally at each release.

## [Unreleased]

### Changed
* Changelog: explain the versioning scheme
* Changelog: add a release date for 9.1.5

## [9.1.5] - 2018-01-18

### Added
* There is changelog!
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

### Changed
* nginx: rename Let's Encrypt snippet

### Removed
* mongodb: logfile/pidfile are not configurable on Jessie

### Fixed
* nginx: fix munin CGI graphs
* ntpd: fix default configuration (localhost only)
