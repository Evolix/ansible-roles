# Evoacme 1.4

EvoAcme is an [Ansible](https://www.ansible.com/) role and a [Certbot](https://certbot.eff.org) wrapper for generate [Let's Encrypt](https://letsencrypt.org/) certificates.

It is a project hosted at [Evolix's forge](https://forge.evolix.org/projects/ansible-roles/repository/revisions/master/show/evoacme)

# How to install

1 - Create a playbook with evoacme role

~~~
---
  - hosts: hostname
    become: yes
    roles:
      - role: evoacme
~~~

2 - Install evoacme prerequisite with ansible

~~~
ansible-playbook playbook.yml -Kl hostname
~~~

3 - Include letsencrypt.conf in your webserver

For Apache, you just need to ensure that you don't overwrite "/.well-known/acme-challenge" Alias with a Redirect or Rewrite directive.

For Nginx, you must include letsencrypt.conf in all wanted vhost :

~~~
include /etc/nginx/letsencrypt.conf;
nginx -t
service nginx reload
~~~

4 - Create a CSR for a vhost with make-csr

~~~
# make-csr look for this file :
# /etc/nginx/sites-enabled/vhostname
# /etc/nginx/sites-enabled/vhostname.conf
# /etc/apache2/sites-enabled/vhostname
# /etc/apache2/sites-enabled/vhostname.conf
make-csr vhostname
~~~

8 - Generate the certificate with evoacme

~~~
# evoacme look for /etc/ssl/requests/vhostname
# vhostname was the same used by make-csr
evoacme vhostname
~~~

# License

Evoacme is open source software licensed under the AGPLv3 License.
