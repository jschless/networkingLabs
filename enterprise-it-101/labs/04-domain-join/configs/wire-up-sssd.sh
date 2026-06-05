#!/bin/bash
# ============================================================
# Post-join wiring (Task 3).
#
# `realm join` would do all of this automatically on a systemd host. Run AFTER
# `adcli join` so the host actually USES the domain for identity and login:
#
#   1. install /etc/sssd/sssd.conf (must be root-owned, mode 0600, or sssd
#      refuses to start)
#   2. tell NSS to look up users/groups in sssd
#   3. enable the pam_sss + pam_mkhomedir PAM modules (login via AD + auto
#      home-directory creation)
#   4. start the sssd daemon
#
# This is the boilerplate the lab is *not* about — the learning is in what
# `adcli join` created (Task 2) and what sssd.conf says (read it!).
# ============================================================
set -e

install -o root -g root -m 0600 /etc/sssd/sssd.conf.lab /etc/sssd/sssd.conf

sed -i 's/^passwd:.*/passwd:         files sss/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:          files sss/'  /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:         files sss/' /etc/nsswitch.conf

DEBIAN_FRONTEND=noninteractive pam-auth-update --enable sss --enable mkhomedir >/dev/null 2>&1

pkill -x sssd 2>/dev/null || true
sleep 1
sssd            # daemonises

# A non-root local account for testing logins. `docker exec` runs as root, and
# root's `su` never checks a password — so to actually exercise AD
# authentication you must `su` from an unprivileged shell. Log in as this user
# first, then `su - <ad-user>`.
id tester >/dev/null 2>&1 || useradd -m -s /bin/bash tester

echo "sssd wired up. Now: su - tester   (then su - alice@lab.corp)"
