# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project tries to adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [9.1.5]

### Added
* There is changelog!
* Redis: configuration variable for protected mode (v3.2+)
* evolinux-users: users are in "adm" group for Debian 9 or later
* evolinx-base: purge locate/mlocate packages
* evolinx-base: create /etc/evolinux if missing
* many Ansible tags for easier fine grained execution of playbooks
* apache/nginx: server status suffix management
* unbound: retrieve list of root DNS servers
* redmine: ability to install thems and plugins

### Changed
* Rbenv: Ruby 2.5 becomes the default version
* evocheck: update upstream version embedded in role (c993244)
* bind: keep 52 weeks of logs

### Fixed
* squid: different logrotate file for Jessie or Stretch+
* evoacme: don't invoke evoacme if no vhost is found
* evomaintenance: explicit quotes in config file
* redmine: force xpath gem < 3.0.0

### Security
* evomaintenance: fix permissions for config file
