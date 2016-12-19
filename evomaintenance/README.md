# evomaintenance

Install a script to notify when operations are performed on a server

The Debian package is available at `pub.evolix.net`.
Make you have `deb http://pub.evolix.net/ jessie/` in your sources list.

## Tasks

Installation and configuration are performed via `tasks/main.yml`.
A shell exit trap is added to users' `.profile` in `tasks/trap.yml`.
