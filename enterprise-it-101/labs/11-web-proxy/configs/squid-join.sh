#!/bin/bash
# ============================================================
# proxy1 — domain join + HTTP service keytab + launch Squid (GIVEN scaffolding).
#
# Joining the domain and minting a Kerberos service keytab for
# HTTP/proxy1.lab.corp is one-time, error-prone plumbing — exactly the kind of
# thing the authoring guide says to hand over. Writing the Squid *auth* and
# *group ACL* config (configs/squid.conf) is the lab; this gets you to the
# starting line with a working keytab.
#
# Runs as the container command. Ends by exec'ing squid in the foreground.
# ============================================================
set -e

REALM="LAB.CORP"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
DC="dc1.lab.corp"
FQDN="proxy1.lab.corp"
KEYTAB="/etc/squid/PROXY.keytab"

echo "==> [proxy1] waiting for the DC's Kerberos KDC..."
for i in $(seq 1 60); do
    if getent hosts "$DC" >/dev/null 2>&1 && (echo > /dev/tcp/dc1.lab.corp/88) 2>/dev/null; then
        echo "==> [proxy1] DC reachable."; break
    fi
    sleep 2
done

# Kerberos client config. rdns=false because the lab DCs have no PTR records —
# without this, GSSAPI canonicalisation would look up a non-existent SPN.
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

# GSSAPI LDAP from the group ACL helper needs SASL_NOCANON: the lab DCs have no
# PTR records, so SASL's reverse-DNS canonicalisation would request a bogus SPN
# (ldap/<reverse-name>) and the bind fails with "Local error".
mkdir -p /etc/ldap
cat > /etc/ldap/ldap.conf <<'EOF'
SASL_NOCANON on
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
EOF

# Minimal member-server smb.conf so `net ads` can join.
cat > /etc/samba/smb.conf <<'EOF'
[global]
    workgroup = LAB
    realm = LAB.CORP
    security = ADS
    kerberos method = secrets and keytab
    log file = /var/log/samba/log.%m
    log level = 1
EOF
mkdir -p /var/log/samba /var/lib/samba

echo "==> [proxy1] joining ${REALM}..."
net ads join -U "Administrator%${ADMIN_PASS}" || { sleep 5; net ads join -U "Administrator%${ADMIN_PASS}"; }

echo "==> [proxy1] registering HTTP/${FQDN} SPN and exporting its keytab..."
net ads setspn add "HTTP/${FQDN}" -U "Administrator%${ADMIN_PASS}" || true
# Export the machine + HTTP keys into a dedicated keytab Squid's helpers read.
net ads keytab create -U "Administrator%${ADMIN_PASS}" || true
net ads keytab add "HTTP/${FQDN}" -U "Administrator%${ADMIN_PASS}" || true
# net writes /etc/krb5.keytab; give Squid its own copy it can read as user proxy.
cp -f /etc/krb5.keytab "${KEYTAB}"
chown proxy:proxy "${KEYTAB}"
chmod 640 "${KEYTAB}"
echo "==> [proxy1] keytab principals:"; klist -k "${KEYTAB}" || true

# Squid runtime dirs + cache init, then run in the foreground.
mkdir -p /var/spool/squid /var/log/squid
chown -R proxy:proxy /var/spool/squid /var/log/squid
# The group-ACL helper (ext_kerberos_ldap_group_acl) has no -k option, so it
# reads KRB5_KTNAME. Point it at the proxy-readable keytab (it needs the machine
# account PROXY1$ key to GSSAPI-bind to LDAP).
export KRB5_KTNAME="${KEYTAB}"

echo "==> [proxy1] initialising Squid cache + starting..."
squid -z -f /etc/squid/squid.conf || true
sleep 2
# Run Squid as a normal daemon (NOT as PID 1) so it writes a real PID file and
# `squid -k reconfigure` works after you edit squid.conf. Keep the container
# alive by tailing the logs (which also makes `docker logs proxy1` useful).
squid -f /etc/squid/squid.conf
sleep 2
echo "==> [proxy1] Squid started (pid $(cat /run/squid.pid 2>/dev/null)); tailing logs."
exec tail -F /var/log/squid/access.log /var/log/squid/cache.log
