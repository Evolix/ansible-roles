# docker-rootless-instance

Install a docker rootless Instance (rootlesskit) for an existing Unix user with use of systemd user instance.

## Available variables

**docker_rootless_user** : Unix user (***required***)
**docker_rootless_user_uid**: Unix user uid (***required***)
**docker_rootless_user_home**: Unix user home (***required***)
**docker_rootfull_disabled**: *false* by default, disable docker for root if set to true

## Example of role usage

~~~
- hosts: hostname
  become: yes
  roles:
  - { role: docker-rootless-instance, docker_rootless_user: 'rootless-user2', docker_rootless_user_uid: '1002', docker_rootless_user_home: '/home/rootless-user2' }
~~~

## Configuration of your docker-rootless-instance instance

Configuration of the instance can be found in `{{ docker_rootless_user_home }}/.docker/config.json`

The docker-rootless-instance data directory is in `{{ docker_rootless_user_home }}/.local/share/docker`

## Usage of systemd docker service

You must use systemctl --user with docker user by connecting via `machinectl shell {{ docker_rootless_user }}@`.

~~~
# Manage systemd instance
systemctl --user start/stop/enable/disable/status docker
# 
journalctl --user -u docker
~~~

## Usage of docker in a docker-rootless-instance

### By connecting to the user via `machinectl shell {{ docker_rootless_user }}@`.

You can issue docker commands as usual.

> Explaination : A docker context is configured to be used within the rootless user to use the docker-rootless-instance.
You can see it with `docker context ls`. You can set the context to use with `docker context use "<context_name>"`

### By using the docker context from root user

The simplest way is to use the --context argument, for instance `docker --context $context ps`

You can also define this function `dockerx() { echo Running \"docker "$@" \" on all contexts ; for context in $(docker context list -q); do echo Running in context : "$context" ; docker --context $context "$@" ;done; }`
It enable you to run a docker command on all context, for instance `dockerx ps` to list all existing containers for all contexts, **However** be careful if you use dockerx for more than listing !

A docker context is automatically added for the root user for each docker-rootless-instance. as root, you can list them by using `docker context ls`.
You can set the context to use with `docker context use "<context_name>"` and use docker commands as usual.

**Warning** : If you set the context, don't forget to put back the default context with `docker context use default` (use `docker context show` to know which context you're using).