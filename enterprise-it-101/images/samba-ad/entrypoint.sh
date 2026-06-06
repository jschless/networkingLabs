#!/bin/bash
# ============================================================
# Samba AD DC container entrypoint.
#
# Lab 01 (manual): AUTO_PROVISION is unset, so this just starts
# supervisord. SAMBA_AUTOSTART defaults to "false", so the samba
# daemon stays down until the student runs /provision.sh, which
# provisions the domain and then `supervisorctl start samba`.
#
# Labs 02+ (cumulative foundation): the override sets
# AUTO_PROVISION=true and SAMBA_AUTOSTART=true, so this script
# provisions and seeds the LAB.CORP domain on first boot (no manual
# step) and supervisord then auto-starts samba.
#
# Provisioning and seeding operate on the local sam.ldb directly and
# do NOT require the samba daemon to be running, so we do them before
# handing PID 1 to supervisord.
# ============================================================
set -e

REALM="${REALM:-LAB.CORP}"
NETBIOS="${NETBIOS:-LAB}"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
DNS_FORWARDER="${DNS_FORWARDER:-8.8.8.8}"

if [ "${AUTO_PROVISION}" = "true" ] && [ ! -f /var/lib/samba/private/sam.ldb ]; then
    echo "==> [entrypoint] Auto-provisioning ${REALM} (cumulative foundation)..."
    rm -f /etc/samba/smb.conf
    rm -rf /var/lib/samba/private/* /var/lib/samba/sysvol/*
    samba-tool domain provision \
        --realm="${REALM}" \
        --domain="${NETBIOS}" \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL \
        --adminpass="${ADMIN_PASS}" \
        --option="dns forwarder = ${DNS_FORWARDER}" \
        --option="ntlm auth = mschapv2-and-ntlmv2-only"
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

    echo "==> [entrypoint] Seeding foundation objects (Lab 01 equivalents)..."
    bash /usr/local/bin/seed-domain.sh
    echo "==> [entrypoint] Provision + seed complete."
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
