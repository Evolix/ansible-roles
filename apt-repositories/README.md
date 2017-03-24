# apt-repositories

A few APT related operations, like easily install backports of change components for repositories.

## Tasks

Tasks are extracted in several files, included in `tasks/main.yml` :

* `backports.yml` : add a sources list for backports ;
* `basics_components.yml` : replace components for the basic sources.

## Available variables

* `apt_repositories_install_backports` : install backports sources (default: `False`) ;
* `apt_repositories_backports_components` : backports sources (default: `main`) ;
* `apt_repositories_change_basics_components` : change basic sources components (default: `False`) ;
* `apt_repositories_backports_components` : basic sources components (default: `main`) ;

## Examples

To add "non-free" and "contrib" components to basic sources lists :

```
{ role: apt-repositories,
    apt_repositories_change_basics_components: True,
    apt_repositories_basics_components: "main non-free contrib"
}
```

To install backports sources lists :

```
{ role: apt-repositories,
    apt_repositories_install_backports: False: True
}
```

To install backports sources lists with "non-free" and "contrib" :

```
{ role: apt-repositories,
    apt_repositories_install_backports: False: True,
    apt_repositories_backports_components: "main non-free contrib"
}
```

To install backports sources lists and have "non-free" and "contrib" for each repository :

```
{ role: apt-repositories,
    apt_repositories_change_basics_components: True,
    apt_repositories_basics_components: "main non-free contrib",
    apt_repositories_install_backports: False: True,
    apt_repositories_backports_components: "main non-free contrib"
}
```
