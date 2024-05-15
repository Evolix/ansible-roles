# Evomaintenance

```.plain
$ evomaintenance --help
evomaintenance is a program that helps reporting what you've done on a server

Usage: evomaintenance
  or   evomaintenance --message="add new host"
  or   evomaintenance --no-api --no-mail --no-commit
  or   echo "add new vhost" | evomaintenance

Options
 -m, --message=MESSAGE       set the message from the command line
     --mail                  enable the mail hook (default)
     --no-mail               disable the mail hook
     --db                    enable the database hook
     --no-db                 disable the database hook (default)
     --api                   enable the API hook (default)
     --no-api                disable the API hook
     --commit                enable the commit hook (default)
     --no-commit             disable the commit hook
     --evocheck              enable evocheck execution (default)
     --no-evocheck           disable evocheck execution
     --auto                  use "auto" mode
     --no-auto               use "manual" mode (default)
 -v, --verbose               increase verbosity
 -n, --dry-run               actions are not executed
     --help                  print this message and exit
     --version               print version and exit
```
