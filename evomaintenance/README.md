# evomaintenance

Install evomaintenance.sh script.
Evomaintenance notify and commit operations performed on a server.

To enable evomaintenance for a user, add this line to it's `.bash_profile` or `.profile` file:

~~~
trap "sudo /usr/share/scripts/evomaintenance.sh" 0
~~~

