# mongodb-org

Install latest MongoDB from 10Gen repository.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

* `mongodb_pidfile_path`: PID file path (default: `/var/lib/mongodb/mongod.lock`)
* `mongodb_logfile_path`: log file path (default: `/var/log/mongodb/mongod.log`)
* `mongodb_port`: port to listen to (default: `27017`)
* `mongodb_bind`: IP to bind to (default: `127.0.0.1`)

The full list of variables (with default values) can be found in `defaults/main.yml`.
