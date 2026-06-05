#!/bin/bash
# ============================================================
# fs1 — Samba domain MEMBER server bootstrap (GIVEN scaffolding).
#
# This is NOT a domain controller. It joins the existing lab.corp domain as
# a member (security = ADS), so it can authenticate users against the DC over
# Kerberos and resolve AD users/groups to local UIDs/GIDs via winbind. Joining
# a member server is one-time, error-prone plumbing — exactly the kind of thing
# the authoring guide says to hand over. Writing the *shares* and *ACLs* is the
# lab; this gets you to the starting line.
#
# Runs as the container command (overriding the samba-ad image's DC entrypoint).
# ============================================================
set -e

REALM="LAB.CORP"
DOMAIN="LAB"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
DC="dc1.lab.corp"

echo "==> [fs1] waiting for the DC's Kerberos KDC to come up..."
for i in $(seq 1 60); do
    if getent hosts "$DC" >/dev/null 2>&1 && \
       (echo > /dev/tcp/dc1.lab.corp/88) 2>/dev/null; then
        echo "==> [fs1] DC reachable."
        break
    fi
    sleep 2
done

# Kerberos client config (the DC is the KDC).
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

# winbind/NSS so AD users & groups resolve to UIDs/GIDs on this box.
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

# Member-server smb.conf. The [global] block is the join/identity scaffolding;
# you add the [engineering] / [finance] / [public] share stanzas yourself.
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

    # Map the LAB domain's RIDs to a stable local UID/GID range so POSIX
    # ACLs on disk line up with AD group membership.
    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config LAB : backend = rid
    idmap config LAB : range = 10000-999999

    # Honour POSIX ACLs and store NT ACLs in xattrs.
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

    log file = /var/log/samba/log.%m
    log level = 1

# ---------------------------------------------------------------------------
# YOUR SHARES GO BELOW (Task 3). Edit this file, then reload:
#   smbcontrol smbd reload-config   (or restart the container's smbd)
# ---------------------------------------------------------------------------
EOF

# Pre-create the share directories (empty; you set ownership/ACLs in the lab).
mkdir -p /srv/shares/engineering /srv/shares/finance /srv/shares/public
mkdir -p /var/log/samba /var/lib/samba

echo "==> [fs1] joining ${REALM} as a member server..."
net ads join -U "Administrator%${ADMIN_PASS}" || {
    echo "==> [fs1] join failed; retrying once after 5s..."; sleep 5
    net ads join -U "Administrator%${ADMIN_PASS}"
}

echo "==> [fs1] starting winbindd + smbd"
winbindd
exec smbd --foreground --no-process-group --debug-stdout
