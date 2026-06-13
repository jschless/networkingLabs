#!/bin/bash
# ============================================================
# radius1 — domain join + winbind + launch FreeRADIUS (GIVEN scaffolding).
#
# Joining the domain (so ntlm_auth can validate MSCHAPv2 against AD) and getting
# winbind's privileged pipe readable by FreeRADIUS is fiddly, one-time plumbing —
# the kind of thing the authoring guide says to hand over. Writing the RADIUS
# *modules*, *clients*, and *policy* is the lab.
#
# Runs as the container command. Ends by running FreeRADIUS in the foreground.
# ============================================================
set -e

REALM="LAB.CORP"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
DC="dc1.lab.corp"

echo "==> [radius1] waiting for the DC's KDC..."
for i in $(seq 1 60); do
    if getent hosts "$DC" >/dev/null 2>&1 && (echo > /dev/tcp/dc1.lab.corp/88) 2>/dev/null; then
        echo "==> [radius1] DC reachable."; break
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

# GSSAPI LDAP needs SASL_NOCANON (lab DCs have no PTR records).
mkdir -p /etc/ldap
cat > /etc/ldap/ldap.conf <<'EOF'
SASL_NOCANON on
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
EOF

cat > /etc/samba/smb.conf <<'EOF'
[global]
    workgroup = LAB
    realm = LAB.CORP
    security = ADS
    winbind use default domain = yes
    template shell = /bin/bash
    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config LAB : backend = rid
    idmap config LAB : range = 10000-999999
    log file = /var/log/samba/log.%m
    log level = 1
EOF

cat > /etc/nsswitch.conf <<'EOF'
passwd:         files winbind
group:          files winbind
shadow:         files
hosts:          files dns
EOF

mkdir -p /var/log/samba /var/lib/samba
echo "==> [radius1] joining ${REALM}..."
net ads join -U "Administrator%${ADMIN_PASS}" || { sleep 5; net ads join -U "Administrator%${ADMIN_PASS}"; }

# FreeRADIUS (user freerad) reads winbind's privileged pipe to run ntlm_auth.
# The supported way is group membership: winbindd creates
# /var/lib/samba/winbindd_privileged as root:winbindd_priv mode 0750, and any
# caller in winbindd_priv may use it. winbindd REFUSES to start if that dir is
# anything other than 0750, so we reset it (a prior run may have left it 0770)
# and clear a stale pid before (re)starting — this makes `restart` idempotent.
getent group winbindd_priv >/dev/null 2>&1 && usermod -aG winbindd_priv freerad 2>/dev/null || true
mkdir -p /var/lib/samba/winbindd_privileged
chgrp winbindd_priv /var/lib/samba/winbindd_privileged 2>/dev/null || true
chmod 0750 /var/lib/samba/winbindd_privileged
rm -f /run/samba/winbindd.pid /var/run/samba/winbindd.pid 2>/dev/null

echo "==> [radius1] starting winbindd..."
winbindd

echo "==> [radius1] waiting for winbindd to be ready..."
for i in $(seq 1 30); do wbinfo -p >/dev/null 2>&1 && break; sleep 1; done

echo "==> [radius1] ntlm_auth sanity (Administrator):"
ntlm_auth --request-nt-key --domain=LAB --username=Administrator --password="${ADMIN_PASS}" || true

# Generate the FreeRADIUS test CA + server/client certs for EAP (PEAP/EAP-TLS).
if [ ! -f /etc/freeradius/3.0/certs/server.pem ]; then
    echo "==> [radius1] generating EAP test certificates..."
    make -C /etc/freeradius/3.0/certs >/dev/null 2>&1 || true
fi
chgrp -R freerad /etc/freeradius/3.0/certs 2>/dev/null || true
chmod -R g+rX /etc/freeradius/3.0/certs 2>/dev/null || true
# Distribute the client cert + CA to the supplicant (nas1) for EAP-TLS.
mkdir -p /shared-certs
cp -f /etc/freeradius/3.0/certs/ca.pem /etc/freeradius/3.0/certs/client.pem \
      /etc/freeradius/3.0/certs/client.key /shared-certs/ 2>/dev/null || true
chmod -R a+rX /shared-certs 2>/dev/null || true

# Enable the LDAP module (mschap + eap are enabled by default).
ln -sf ../mods-available/ldap /etc/freeradius/3.0/mods-enabled/ldap

# Run FreeRADIUS in the foreground. Set RADIUS_DEBUG=1 to get full -X tracing.
mkdir -p /var/log/freeradius
chown -R freerad:freerad /var/log/freeradius
echo "==> [radius1] starting FreeRADIUS..."
if [ "${RADIUS_DEBUG}" = "1" ]; then
    exec freeradius -X
else
    exec freeradius -f -l stdout
fi
