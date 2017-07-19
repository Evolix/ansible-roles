# apt

A few APT related operations, like easily install backports of change components for repositories.

## Tasks

Tasks are extracted in several files, included in `tasks/main.yml` :

* `backports.yml` : add a sources list for backports ;
* `basics_components.yml` : replace components for the basic sources.

## Available variables

* `apt_install_basics` : change basic sources components (default: `True`) ;
* `apt_basics_components` : basic sources components (default: `main`) ;
* `apt_install_backports` : install backports sources (default: `False`) ;
* `apt_backports_components` : backports sources (default: `main`) ;
* `apt_install_evolix_public` : install Evolix public repositories (default: `True`).

## Examples

To add "non-free" and "contrib" components to basic sources lists :

```
{ role: apt,
    apt_install_basics: True,
    apt_basics_components: "main non-free contrib"
}
```

To install backports sources lists :

```
{ role: apt,
    apt_install_backports: True
}
```

To install backports sources lists with "non-free" and "contrib" :

```
{ role: apt,
    apt_install_backports: True,
    apt_backports_components: "main non-free contrib"
}
```

To install backports sources lists and have "non-free" and "contrib" for each repository :

```
{ role: apt,
    apt_install_basics: True,
    apt_basics_components: "main non-free contrib",
    apt_install_backports: True,
    apt_backports_components: "main non-free contrib"
}
```
