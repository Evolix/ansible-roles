# docker-host
- Author: Gabriel Périard-Tremblay <gperiardtremblay@evolix.ca>
- Date: August 2016

## What docker-host Affects

This playbook will install a docker-engine on the target host.

## Role Variables

Useful variables :

- **docker_home** path to where docker will store its internals **and** docker volumes, default is `/var/lib/docker`. It's **recommended to use a specific partition** ( `/home/docker` or `/srv/docker` ) to avoid filling 100% `/var`
- **docker_conf_live_restore** allow containers to not be restarted upon update of docker, it **needs** to be turned **off** to use docker **swarm**. Default is `true`
- **docker_conf_user_namespace**, enable by default the use of "user namespacing" when creating containers. brings it's on [set of challenges](https://wiki.evolix.org/HowtoDocker#activer-le-userns-remap), but allow for safer containers. Default is `true`

These variables are needed when the docker-engine needs to be exposed.

- docker_remote_access_enabled: True
- docker_daemon_port: 2376
- docker_daemon_listening_ip: 0.0.0.0

When the docker-engine is reachable from another host, it's important
to configure TLS. Those are the basic settings for TLS and it should not be
modified.

- docker_tls_enabled: True
- docker_tls_path: /home/docker/tls
- docker_tls_ca: ca/ca.pem
- docker_tls_ca_key: ca/ca-key.pem
- docker_tls_cert: server/cert.pem
- docker_tls_key: server/key.pem
- docker_tls_csr: server/server.csr

## Example

`$ ansible-playbook -i inventory docker-host.yml`

## License

GPLv3
