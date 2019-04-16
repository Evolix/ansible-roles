# Ansible-roles

A repository for Ansible roles used by Evolix on Debian GNU/Linux 9 (stretch) servers.
Few roles are also be compatible with Debian GNU/Linux 8 (jessie) servers.

It contains only roles, everything else is available at
https://gitea.evolix.org/evolix/ansible-public

## Branches

The **stable** branch contains roles that we consider ready for production.

The **unstable** branch contains not sufficiently tested roles (or evolutions on existing roles) that we don't consider ready for production yet.

Many feature branches may exist in the repository. They represent "work in progress". They may be used, for testing purposes.

## Install and usage

First, check-out the repository :

```
$ cd ~/GIT/
$ git clone https://gitea.evolix.org/evolix/ansible-roles
```

Then, add its path to your ansible load path :

```
$ vim ~/.ansible.cfg
[defaults]
roles_path = $HOME/GIT/ansible-roles
```

Then, include roles in your playbooks :

```
- hosts: all
  gather_facts: yes
  become: yes
  roles:
    - etc-git
    - evolinux-base
```

## Contributing

Contributions are welcome, especially bug fixes and "ansible good practices". They will be merged in if they are consistent with our conventions and use cases. They might be rejected if they introduce complexity, cover features we don't need or don't fit "style".

Before starting anything of importance, we suggest contacting us to discuss what you'd like to add or change.

Our conventions are available in the "ansible-public":https://gitea.evolix.org/evolix/ansible-public repository, in the CONVENTIONS.md file.

## Workflow

The ideal and most typical workflow is to create a branch, based on the "unstable" branch. The branch should have a descriptive name (a ticket/issue number is great). The branch can be treated as a pull-request or merge-request. It should be propery tested and reviewed before merging into "unstable".

Changes that don't introduce significant changes — or that must go faster that the typical workflow — can be commited directly into "unstable".

Hotfixes, can be prepared on a new branch, based on "stable" or "unstable" (to be decided by the author). When ready, it can be merged back to "stable" for immediate deployment and to "unstable" for proper backporting.

Other workflow are not forbidden, but should be discussed in advance.
