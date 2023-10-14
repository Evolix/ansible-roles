# PgBouncer

Installation and basic configuration of PgBouncer.

## Tasks

Everything is in the `tasks/main.yml` file.

## Available variables

Main variables are :

* `pgbouncer_listen_addr`: the listen IP for PgBouncer (default: `127.0.0.1`),
* `pgbouncer_listen_port`: the listen post for PgBouncer (default: `6432`),
* `pgbouncer_databases`: the databases that clients of PgBouncer can connect to,
* `pgbouncer_account_list`: the accounts that clients of PgBouncer can connect to.
* `pgbouncer_auth_type`: the variable `auth_type` define by default to `scram-sha-256`, if you installed PgBouncer on PostgreSQL version inferior to 14, set this variable to `md5`.

The variable `pgbouncer_databases` must have the `name`, `host` and `port` attributes. The variable can be defined like this:

```
pgbouncer_databases:
  - { name: "db1", host: "192.168.3.14", port: "5432" }
  - { name: "*", host: "192.168.2.71", port: "5432" }
```

The variable `pgbouncer_account_list` must have the `name` and `hash` attributes. The variable can be defined like this:

```
pgbouncer_account_list:
  - { name: "account1", hash: "<hash>" }
  - { name: "account2", hash: "<hash>" }
```

The value of `hash` can be obtained by running this command on the PostgreSQL server:

```
select passwd from pg_shadow where usename='account1';
```

> These accounts must exist on the PostgreSQL server.

The variables `pgbouncer_admin_users` and `pgbouncer_stats_users` list the SQL user can be access on pgbouncer console. This variables can be defines like this :

```
pgbouncer_admin_users:
   - account1
   - account2
```

```
pgbouncer_stats_users:
   - account1
   - account2
```

The full list of variables (with default values) can be found in `defaults/main.yml`.
