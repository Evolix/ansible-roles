# lxc

Install and configure lxc and create containers.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Here is the list of available variables:

* `lxc_unprivilegied_containers`: should LXC containers run in unprivilegied (non root) mode? Default: `true`
* `lxc_network_type`: network type to use. See lxc.container.conf(5). Default: `"none"`
* `lxc_mount_part`: partition to bind mount into containers. Default: `"/home"`
* `lxc_containers`: list of LXC containers to create. Default: `[]` (empty).
  Eg.:
  ```
  lxc_containers:
    - name: php56
      release: jessie
    - name: php70
      release: stretch
   ```
