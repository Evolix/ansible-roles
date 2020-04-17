# mongodb

Install MongoDB

We use Debian packages for Stretch, but MongoDB.org packages for Jessie/Buster

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `mongodb_port`: port to listen to (default: `27017`)
* `mongodb_bind`: IP to bind to (default: `127.0.0.1`)
* `mongodb_force_config`: force copy the configuration (default: `false`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
