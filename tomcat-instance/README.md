# tomcat-instance

Install a Tomcat Instance with an independent Unix user and use of systemd user instance.

## Available variables

**tomcat_instance_name **: Name of Tomcat instance and proprietary user and group (***required***)
**tomcat_instance_root:** Root dir for Tomcat instance (default: /srv/tomcat)
**tomcat_instance_port**: HTTP port for Tomcat instance and uid/gid for Tomcat user and group (default: 8080)
**tomcat_instance_shutdown**: Port for Tomcat shutdown (default: HTTP port + 1)
**tomcat_instance_ram**: Max memory for Tomcat instance (default: 512)
**tomcat_instance_mps**: Max memory for internal objects of Tomcat instance (default: ram / 2)
**tomcat_instance_mail**: Mail adresse for sending mail on shutdown instance (default to Unix user)
**tomcat_instance_deploy_user**: Unix user who have sudo right with no password for application deployement

## Exemple of role usage

~~~
- hosts: hostname
  become: yes
  vars:
    - tomcat_instance_mail: 'test@example.com'
    - tomcat_instance_deploy_user: 'deploy'
  roles:
  - { role: tomcat-instance, tomcat_instance_name: 'instance1', tomcat_instance_port: 8888, tomcat_instance_ram: 2048 }
~~~

## Configuration of your Tomcat instance

Once you instance was installed, you can managed it with members of Tomcat instance group, deploy_user or directly by Tomcat instance owner.

### Environnment config of Tomcat instance

The ~/conf/env file was sourced by systemd Tomcat service, you must define your environnment variables in this file, default value was :

~~~
JAVA_HOME="/usr/lib/jvm/java-1.7.0-openjdk-amd64"
JAVA_OPTS="-server -Xmx512m -Xms512m -XX:MaxPermSize=256m -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+CMSPermGenSweepingEnabled -XX:+CMSClassUnloadingEnabled -Xverify:none"
~~~

### Usage of systemd Tomcat service

You must use systemctl --user with Tomcat user by **su - username** or prefix command by **sudo -iu username** ;

~~~
systemctl --user start tomcat
systemctl --user stop tomcat
systemctl --user status tomcat
systemctl --user restart tomcat
systemctl --user enable tomcat
systemctl --user disable tomcat
~~~

Alias scripts was availables in ~/bin/ for easier use if you are in Tomcat instance group or if you are deploy_user .

~~~
~/bin/startup.sh
~/bin/shutdown.sh
~/bin/status.sh
~/bin/enable.sh
~/bin/disable.sh
~~~
