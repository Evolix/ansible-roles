# lxc-solr
  
Create one or more LXC containers with Solr in the version of your choice.

*note : this role depend on the lxc role.*

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Since this role depend on the lxc role, please refer to it for a full variable list related to the lxc containers setup.

* `lxc_containers`: list of LXC containers to create. Default: `[]` (empty).
  * `name`: name of the LXC container to create.
  * `release`: Debian version to install
  * `solr_version`: Solr version to install *(refer to https://archive.apache.org/dist/solr/solr/ for a full version list)*
  * `solr_port`: port for Solr to listen on
  Eg.:
  ```
  lxc_containers:
    - name: solr8
      release: stretch
      solr_version: 6.6.6
      solr_port: 8983
   ```
