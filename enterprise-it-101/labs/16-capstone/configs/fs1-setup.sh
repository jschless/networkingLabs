#!/bin/bash
# ============================================================
# fs1 — Samba domain MEMBER server (CAPSTONE: fully built).
#
# Unlike Lab 07 (which handed over only the join scaffolding and made the
# student write the shares), the capstone boots fs1 already serving the
# engineering / finance / public shares with group ACLs in place — the
# enterprise is live. Part A verifies Dave (engineering) can write to
# engineering but is refused at finance.
# ============================================================
set -e

REALM="LAB.CORP"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
DC="dc1.lab.corp"

echo "==> [fs1] waiting for the DC's Kerberos KDC..."
for i in $(seq 1 60); do
    if getent hosts "$DC" >/dev/null 2>&1 && (echo > /dev/tcp/dc1.lab.corp/88) 2>/dev/null; then
        echo "==> [fs1] DC reachable."; break
    fi
    sleep 2
done

cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
[realms]
    ${REALM} = {
        kdc = ${DC}
        admin_server = ${DC}
    }
EOF

cat > /etc/nsswitch.conf <<'EOF'
passwd:         files winbind
group:          files winbind
shadow:         files
hosts:          files dns
networks:       files
protocols:      db files
services:       db files
ethers:         db files
rpc:            db files
netgroup:       nis
EOF

# Member-server smb.conf WITH the three shares already defined.
cat > /etc/samba/smb.conf <<'EOF'
[global]
    workgroup = LAB
    realm = LAB.CORP
    security = ADS
    kerberos method = secrets and keytab

    winbind use default domain = yes
    winbind refresh tickets = yes
    winbind enum users = yes
    winbind enum groups = yes
    template shell = /bin/bash
    template homedir = /home/%U

    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config LAB : backend = rid
    idmap config LAB : range = 10000-999999

    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

    log file = /var/log/samba/log.%m
    log level = 1

[engineering]
    path = /srv/shares/engineering
    read only = no
    valid users = @engineering

[finance]
    path = /srv/shares/finance
    read only = no
    valid users = @finance

[public]
    path = /srv/shares/public
    read only = no
    valid users = @all-staff
EOF

mkdir -p /srv/shares/engineering /srv/shares/finance /srv/shares/public
mkdir -p /var/log/samba /var/lib/samba

echo "==> [fs1] joining ${REALM} as a member server..."
net ads join -U "Administrator%${ADMIN_PASS}" || {
    echo "==> [fs1] join failed; retrying once after 5s..."; sleep 5
    net ads join -U "Administrator%${ADMIN_PASS}"
}

echo "==> [fs1] starting winbindd"
winbindd

# Wait for winbind to resolve the AD groups before applying group ACLs.
echo "==> [fs1] waiting for winbind to resolve AD groups..."
for i in $(seq 1 30); do
    if getent group engineering >/dev/null 2>&1; then echo "==> [fs1] groups resolve."; break; fi
    sleep 2
done

# Apply ownership + POSIX ACLs so on-disk permissions line up with AD groups.
chgrp engineering /srv/shares/engineering; chmod 2770 /srv/shares/engineering
setfacl -m g:engineering:rwx /srv/shares/engineering
chgrp finance /srv/shares/finance;         chmod 2770 /srv/shares/finance
setfacl -m g:finance:rwx /srv/shares/finance
chgrp all-staff /srv/shares/public;        chmod 2775 /srv/shares/public

echo "==> [fs1] starting smbd"
exec smbd --foreground --no-process-group --debug-stdout
