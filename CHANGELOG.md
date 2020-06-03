# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project does not follow semantic versioning.
The **major** part of the version is aligned with the stable version of Debian.
The **minor** part changes with big changes (probably incompatible).
The **patch** part changes incrementally at each release.

## [Unreleased]

### Added
* mysql: activate binary logs by specifying log_bin path
* mysql: specify a custom server_id
* mysql: option to define as read only

### Changed

* packweb-apache: Don't turn on mod-evasive emails by default
* haproxy: chroot and socket path are configurable
* redis: create sudoers file if missing
* redis: new syntax for match filter
* redis: raise an error is port 6379 is used in "instance" mode
* evoacme: upstream release 20.06

### Fixed

### Removed

### Security

## [10.0.0] - 2020-05-13

### Added
* apache: the default VHost doesn't redirect to https for ".well-known" paths
* apt: added buster backports prerferences
* apt: check if cron is installed before adding a cron job
* apt: remove jessie/buster sources from Gandi servers
* apt: verify that /etc/evolinux is present
* certbot : new role to install and configure certbot
* etc-git: add versioning for /usr/share/scripts on Debian 10+
* evoacme: upstream version 19.11
* evolinux-base: default value for "evolinux_ssh_group"
* evolinux-base: install /sbin/deny
* evolinux-base: install Evocheck (default: `True`)
* evolinux-base: on debian 10 and later, add noexec on /dev/shm
* evolinux-base: on debian 10 and later, add /usr/share/scripts in root's PATH
* evolinux-base: remove the chrony package
* evomaintenance: don't configure firewall for database if not necessary
* generate-ldif: support MariaDB 10.3
* haproxy: add a variable to keep the existing configuration
* java: add Java 11 as possible version to install
* listupgrade: install old-kernel-autoremoval script
* minifirewall: add a variable to force the check scripts update
* mongodb: mongodb: compatibility with Debian 10
* mysql-oracle: backport tasks from mysql role
* networkd-to-ifconfig: add variables for configuration by variables
* packweb-apache: Deploy opcache.php to give some insights on PHP's opcache status
* php: variable to install the mysqlnd module instead of the default mysql module
* postgresql : variable to install PostGIS (default: `False`)
* redis: rewrite of the role (separate instances, better systemd units…)
* webapps/evoadmin-web Add an htpasswd to evoadmin if you cant use an apache IP whitelist
* webapps/evoadmin-web Overload templates if needed
* evolinux-base: install ssacli for HP Smart Array
* evobackup-client role to configure a machine for backups with bkctld(8)
* bind: enable query logging for recursive resolvers
* bind: enable logrotate for recursive resolvers
* bind: enable bind9 munin plugin for recursive resolvers

### Changed
* replace version_compare() with version()s
* removed some deprecations for Ansible 2.7
* apache: improve permissions in save_apache_status script
* apt: hold packages only if package is installed
* bind: the munin task was present, but not included
* bind: change name of logrotate file to bind9
* certbot: commit hook must be executed at the end
* elasticsearch: listen on local interface only by default
* evocheck: upstream version 20.04.4
* evocheck: cron jobs execute in verbose
* evolinux-base: use "evolinux_internal_group" for SSH authentication
* evolinux-base: Don't customize the logcheck recipient by default.
* evolinux-base: configure cciss-vol-statusd in the proper file
* evomaintenance: upstream release 0.6.3
* evomaintenance: Turn on API by default (instead of DB)
* evomaintenance: install PG dependencies only when needed
* listupgrade: update from upstream
* lxc: rely on lxc_container module instead of command module
* lxc: remove useless loop in apt execution
* lxc: update our default template to be compatible with Debian 10
* lxc-php: refactor tasks for better maintainability
* lxc-php: Use OpenSMTPD for Stretch/Buster containers, and ssmtp for Jessie containers
* lxc-solr: changed default Solr version to 8.4.1
* minifirewall: better alert5 activation
* minifirewall: no http filtering by default
* minifirewall: /bin/true command doesn't report "changed" anymore
* nagios-nrpe: update check_redis_instances (same as redis role)
* nagios-nrpe: change default haproxy socket path
* nagios-nrpe: check_mode per cpu dynamically
* nodejs: change default version to 12 (new LTS)
* packweb-apache: Do the install & conffigure phpContainer script (instead of evoadmin-web role)
* php: By default, allow 128M for OpCache (instead of 64M)
* php: Don't set a chroot for the default fpm pool
* php: Make sure the default pool we define can be fully functionnal witout debian's default pool file
* php: Change the default pool names to something more explicit (and same for the variables names)
* php: Add a task to remove Debian's default FPM pool file (off by default)
* php: Cleanup CLI Settings. Also, allow url fopen and don't disable functions (in CLI only)
* postgresql : changed logrotate config to 10 days (and fixed permissions)
* rbenv: changed default Ruby version to 2.7.0
* squid: Remove wait time when we turn off squid
* squid: compatibility wit Debian 10
* tomcat: package version derived from Debian version if missing
* varnish: remove custom ExecReload= script for Debian 10+

### Fixed
* etc-git: fix warnings ansible-lint
* evoadmin-web: Put the php config at the right place for Buster
* lxc: Don't stop the container if it already exists
* lxc: Fix container existance check to be able to run in check_mode
* lxc-php: Don't remove the default pool
* minifirewall: fix warnings ansible-lint
* nginx: fix munin fcgi not working (missing chmod 660 on logs)
* php: add missing handler for php7.3-fpm
* roundcube: fix typo for roundcube vhost
* tomcat: fix typo for default tomcat_version
* evolinux-base: Fix our zsyslog rotate config that doesn't work on Debian 10
* certbot: Properly evaluate when apache is installed
* evolinux-base: Don't make alert5.service executable as systemd will complain
* webapps/evoadmin-web: Set default evoadmin_mail_tpl_force to True to fix a regression where the mail template would not get updated because the file is created before the role is first run.
* minifirewall: Backport changes from minifirewall (properly open outgoing smtp(s))
* minifirewall: Properly detect alert5.sh to turn on firewall at boot
* packweb-apache: Add missing dependency to evoacme role
* php: Chose the debian version repo archive for packages.sury.org
* php: update surry_post.yml to match current latest PHP release
* packweb-apache: Don't try to install PHPMyAdmin on Buster as it's not available

### Removed
* clamav : do not install the zoo package anymore

## [9.10.1] - 2019-06-21

### Changed
* evocheck : update (version 19.06) from upstream

## [9.10.0] - 2019-06-21

### Added
* apache: add server status suffix in VHost (and default site) if missing
* apache: add a variable to customize the server-status host
* apt: add a script to manage packages with "hold" mark
* etc-git: gitignore /etc/letsencrypt/.certbot.lock
* evolinux-base: install "spectre-meltdown-checker" (Debian 10 and later)
* evomaintenance: make hooks configurable
* nginx: add server status suffix in VHost (and default site) if missing
* redmine: enable gzip compression in nginx vhost

### Changed
* evocheck : update (unreleased) from upstream
* evomaintenance : use the web API instead of PG Insert
* fluentd: store gpg key locally
* rbenv: update defaults rbenv version to 1.1.2 and ruby version to 2.6.3
* redmine: update default version to 4.0.3
* nagios-nrpe: change required status code for http and https check
* redmine: use custom errors-pages in Nginx vhost
* nagios-nrpe: check_load is now based on ansible_processor_vcpus
* php: Stop enforcing /var/www/html as chroot while we use /var/www
* apt: Add Debian Buster repositories

### Fixed
* rbenv: add check_mode for check rbenv and ruby versions
* nagios-nrpe: fix redis_instances check when Redis port equal 0
* redmine: fix 500 error on logging
* evolinux-base: Validate sshd config with "-t" instead of "-T"
* evolinux-base: Ensure rename is present
* evolinux-users: Validate sshd config with "-t" instead of "-T"
* nagios-nrpe: Replace the dummy packages nagios-plugins-* with monitoring-plugins-*

## [9.9.0] - 2019-04-16

### Added
* etc-git: ignore evobackup/.keep-* files
* lxc: /home is mounted in the container by default
* nginx : add "x-frame-options: sameorigin" for Munin

### Changed
* changed remote repository to https://gitea.evolix.org/evolix/ansible-roles
* apt: Ensure jessie-backport from archives.debian.org is accepted
* apt: Remove jessie-update suite as it's no longer exists
* apt: Replace mirror.evolix.org by archives.debian.org for jessie-backport
* evocheck : update script from upstream
* evolinux-base: remove apt-listchanges on Stretch and later
* evomaintenance: embed version 0.5.0
* opendkim: aligning roles with our conventions, major changes in opendkim-add.sh
* redis: higher limit of open files
* redis: set variables on inclusion, not with set_facts
* tomcat: better tomcat version management
* webapps/evoadmin-web: add dbadmin.sh to sudoers file


### Fixed
* spamassasin: fix sa-update.sh and ensure service is started and enabled
* tomcat-instance: deploy correct version of config files
* tomcat-instance: deploy correct version of server.xml

## [9.8.0] - 2019-01-31

### Added
* filebeat: disable cloud_metadata processor by default
* metricbeat: disable cloud_metadata processor by default
* percona : new role to install Percona repositories and tools
* redis: add variable for configure unixsocketperm

### Changed
* redmine: refactoring of redmine role with use of rbenv

### Fixed
* ntpd: Update the restrictions to follow wiki.evolix.org/HowtoNTP client config

## [9.7.0] - 2019-01-17

### Added
* apache: add Munin configuration for Apache server-status URL
* evomaintenance: database variables must be set or the task fails
* fail2ban: add "ips" tag added to fail2ban/tasks/ip_whitelist.yml
* metricbeat: add a variable for the protocol to use with Elasticsearch
* rbenv: add pkg-config to the list of packages to install
* redis: Configure munin when working in instance mode
* redis: add a variable for renamed/disabled commands
* redis: add a variable to disable the restart handler
* redis: add a variable to force a restart (even with no change)
* proftpd: add FTPS and SFTP support

### Changed
* redis: distinction between main and master password
* evocheck: update evocheck.sh for source install
* php: added php-zip in the installed package list for debian 9 (and later)
* squid: added packagist.org in the whitelist
* java: update Oracle java package to 8u192

### Fixed
* fail2ban: fix "ignoreip" update
* metricbeat: fix username/password replacement
* nagios-nrpe: check_process now return the error code (making the check more usefull than /bin/true)
* nginx: Munin url config is now a template to insert the server-status prefix
* nodejs: Update yarn repo GPG key (current key expired)
* redis: In instance mode, ensure to replace the nrpe check_redis with the instance check script
* redis: Don't set the owner of /var/{lib,log}/redis to a redis instance account


## [9.6.0] - 2018-12-04

### Added
* evolinux-base: deploy custom motd if template are present
* minifirewall: all variables are configurable (untouched by default)
* minifirewall: main file is configurable
* squid: minifirewall main file is configurable

### Changed
* minifirewall: compare config before/after (for restart condition)
* squid: better replacement in minifirewall config
* evoadmin-mail: complete refactoring, use Debian Package

## [9.5.0] - 2018-11-14

### Added
* apache: separate task to update IP whitelist
* evolinux-base: install man package
* evolinux-users: add newaliases handler
* evomaintenance: FROM domain is configurable
* fail2ban: separate task to update IP whitelist
* nginx: add tag for ips management
* nginx: separate task to update IP whitelist
* postfix: enable SSL/TLS client
* ssl: add an SSL role for certificates deployment
* haproxy: add vars for tls configuration
* mysql: logdir can be customized

### Changed
* evocheck: update script from upstream
* evomaintenance: update script from upstream
* mysql: restart service if systemd unit has been patched

### Fixed
* packweb-apache: mod-security config is already included elsewhere
* redis: for permissions on log and lib directories
* redis: fix shell for instance users
* evoacme: fix error handling in sed_cert_path_for_(apache|nginx)

## [9.4.2] - 2018-10-12

### Added
* evomaintenance: install dependencies manually when installing vendored version
* nagios-nrpe: add an option to ignore servers in NOLB status

### Changed
* haproxy: move check_haproxy_stats to nagios-nrpe role

### Fixed
* evoacme: better error when apache2ctl fails
* evomaintenance: fix role compatibility with OpenBSD
* spamassassin: add missing right for amavis
* amavis: fix output result checking

## [9.4.1] - 2018-09-28

### Added
* redis: set masterauth when redis_password is defined
* evomaintenance: variable to install a vendored version
* evomaintenance: tasks/variables to handle minifirewall restarts

### Changed
* mysql-oracle: better handle packages and users

## [9.4.0] - 2018-09-20

### Added
* etc-git: manage a cron job to monitor uncommited changes in /etc/.git (default: `True`)
* evolinux-base: better shell history
* evolinux-users: add user to /etc/aliases
* generate-ldif: add a section for postgresql
* logstash: tmp directory can be customized
* logstash: max memory is set to 512M by default
* logstash: version 6.x is installed by default
* mysql: add a variable to prevent mysql from restarting
* networkd-to-ifconfig: add a role to switch from networkd to ifconfig
* webapps/evoadmin-web: add users to /etc/aliases
* redis: add support for multi instances
* nagios-nrpe: add check_redis_instances

### Changed
* dovecot: stronger TLS configuration

### Fixed
* apache: cleaner way to overwrite the server status suffix
* packweb-apache: don't regenerate phpMyAdmin suffix each time
* nginx: cleaner way to overwrite the server status suffix
* redis: add missing tags

## [9.3.2] - 2018-09-06

### Added
* minifirewall: add a variable to disable the restart handler
* minifirewall: add a variable to force a restart of the firewall (even with no change)
* minifirewall: improve variables values and documentation

### Changed
* dovecot: enable SSL/TLS by default with snakeoil certificate

### Fixed

### Security

## [9.3.1] - 2018-08-30

### Added
* metricbeat: new variables to configure elasticsearch hosts and auth

## [9.3.0] - 2018-08-24

### Added
* elasticsearch: tmpdir configuration compatible with 5.x also
* elasticsearch: add http.publish_host variable
* evoacme: disable old certbot cron also in cron.daily
* evocheck: detect installed packages even if "held" by APT (manual fix)
* evocheck: the crontab is updated by the role (default: `True`)
* evolinux-base: add mail related aliases
* evolinux-todo: new role, to help maintain a file of todo tasks
* fail2ban: add a variable to disable the ssh filter (default: `False`)
* etc-git: install a script to optimize the repository each month
* fail2ban: add a variable to update the list of ignored IP addresses/blocs (default: `False`)
* generate-ldif: detect installed packages even if "held" by APT
* java: support for Oracle JRE
* kibana: log messages go to /var/log/kibana/kibana.log
* metricbeat: add a role (copied from filebeat)
* munin: properly rename Munin cache directory
* mysql: add an option to install the client development  libraries (default: `False`)
* mysql: add a few variables to customize the configuration
* nagios-nrpe: add check_postgrey

### Changed
* etc-git: some entries of .gitignore are mandatory
* evocheck: update upstream script
* evolinux-base: improve hostname configuration (real vs. internal)
* evolinux-base: use the "evolinux-todo" role
* evolinux-users: add sudo permission for bkctld check
* java8: renamed to java (java8 symlinked to java for backward compatibility)
* minifirewall: the tail file can be overwritten, or not (default: `True`)
* nagios-nrpe: use bkctld internal check instead of nrpe plugin
* php: reorganization of the role for Sury overrides and more clear configuration
* redmine: use .my.cnf for mysql password
* rbenv: change default Ruby version (2.5.1)
* rbenv: switch from copy to lineinfile for default gems
* remount-usr: mount doesn't report a change
* squid: add a few news sites to the whitelist
* tomcat: better nrpe check output
* kvm-host: install kvm-tools package instead of copying add-vm.sh

### Fixed
* apache: logrotate replacement is more subtle/precise. It replaces only the proper directive and not every occurence of the word.
* bind: chroot-bind.sh must not be executed in check mode
* evoacme: fix module detection in apache config
* fail2ban: fix fail2ban_ignore_ips definition
* mysql-oracle: fix configuration directory variable
* php: fpm slowlog needs an absolute path
* roundcube: add missing slash to https redirection

## [9.2.0] - 2018-05-16

### Changed
* filebeat: install version 6.x by default
* filebeat: cleanup unused code
* squid: add some domaine and fix broken restrictions
* elasticsearch: defaults to version 6.x

### Fixed
* evolinux-users: secondary groups are comma-separated
* ntpd: fix configuration (server and ACL)
* varnish: don't fork the process on startup with systemd

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
