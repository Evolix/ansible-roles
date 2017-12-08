# remount-usr

This is a role for mount /usr partition in rw and remount it with a handler.
Usefull when you use ro option in your /etc/fstab for /usr partition.

## Usage

Include this role in task before write on /usr partition (eg. copy a file) :

~~~
- include_role:
    name: remount-usr
~~~
