# Evoacme 2.0

The upstream repository of EvoAcme is at <https://gitea.evolix.org/evolix/evoacme>

Shell scripts are copied from the upstream repository after each release.
No changes must be applied directly here ; patch upstream, release then copy here.

## Install

### 1 - Create a playbook with evoacme role

~~~
---
- hosts: hostname
  become: yes
  roles:
    - evoacme
~~~

### 2 - Install evoacme prerequisite with ansible

~~~
# ansible-playbook playbook.yml -K --limit hostname
~~~

### 3 - Include letsencrypt.conf in your webserver

For Apache, you just need to ensure that you don't overwrite "/.well-known/acme-challenge" Alias with a Redirect or Rewrite directive.

For Nginx, you must include `/etc/nginx/snippets/letsencrypt.conf` in all wanted vhosts :

~~~
server {
    […]
    include /etc/nginx/snippets/letsencrypt.conf;
    […]
}
~~~

then reload the Nginx configuration :

~~~
# nginx -t
# service nginx reload
~~~

### 4 - Create a CSR for a vhost with make-csr

~~~
# make-csr vhostname domain...
~~~

### 5 - Generate the certificate with evoacme

~~~
# evoacme look for /etc/ssl/requests/vhostname
# vhostname was the same used by make-csr
evoacme vhostname
~~~

### 6 - Include ssl configuration

Sll configuration has generated, you must include it in your vhost.

For Apache :

~~~
Include /etc/apache2/ssl/vhost.conf
~~~

For Nginx :

~~~
include /etc/nginx/ssl/vhost.conf;
~~~
