#!/bin/sh

# Evolix sa-update, based on:
# Duncan Findlay
# duncf@debian.org

mail=$(grep EVOMAINTMAIL /etc/evomaintenance.cf | cut -d'=' -f2)
test -x /usr/bin/sa-update || exit 0
test -x /etc/init.d/spamassassin || exit 0

# If there's a problem with the ruleset or configs, print the output
# of spamassassin --lint (which will typically get emailed to root)
# and abort.
die_with_lint() {
    su - debian-spamd -c "spamassassin --lint -D 2>&1"
    exit 1
}

do_compile() {
# Compile, if rules have previously been compiled, and it's possible
    if [ -x /usr/bin/re2c -a -x /usr/bin/sa-compile \
        -a -d /var/lib/spamassassin/compiled ]; then
        su - debian-spamd -c "sa-compile --quiet"
        # Fixup perms -- group and other should be able to
        # read and execute, but never write.  Works around
        # sa-compile's failure to obey umask.
            chmod -R go-w,go+rX /var/lib/spamassassin/compiled
    fi
}

# Tell a running spamd to reload its configs and rules.
reload() {
    # Reload
    if which invoke-rc.d >/dev/null 2>&1; then
        invoke-rc.d spamassassin reload > /dev/null
    else
        /etc/init.d/spamassassin reload > /dev/null
    fi
    if [ -d /etc/spamassassin/sa-update-hooks.d ]; then
        run-parts --lsbsysinit /etc/spamassassin/sa-update-hooks.d
    fi
}

# Update
umask 022
su - debian-spamd -c "sa-update --gpghomedir /var/lib/spamassassin/sa-update-keys"

case $? in
    0)
        # got updates!
        su - debian-spamd -c "spamassassin --lint" || die_with_lint
        do_compile
        reload
        echo -e "Les règles SpamAsassin ont été mises à jour. Merci de reporter toute anomalie." | \
            mail -s "SpamAsassin's rules updated." $mail
        ;;
    1)
        # no updates
        exit 0
        ;;
    2)
        # lint failed!
        die_with_lint
        ;;
    *)
        echo "sa-update failed for unknown reasons" 1>&2
        ;;
esac
