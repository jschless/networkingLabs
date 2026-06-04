#!/bin/bash
# ============================================================
# Samba AD domain provision script
#
# Run this INSIDE the dc1 container to set up the LAB.CORP domain.
# After provisioning, start Samba with: supervisorctl start samba
# ============================================================

set -e

REALM="LAB.CORP"
DOMAIN="LAB"
ADMIN_PASS="P@ssw0rd1"
DNS_FORWARDER="8.8.8.8"

echo "==> Removing any previous Samba config..."
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*
rm -rf /var/lib/samba/sysvol/*

echo "==> Provisioning Samba AD domain: ${REALM}..."
samba-tool domain provision \
    --realm="${REALM}" \
    --domain="${DOMAIN}" \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --adminpass="${ADMIN_PASS}" \
    --option="dns forwarder = ${DNS_FORWARDER}"

echo "==> Copying Kerberos config..."
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "==> Starting Samba via supervisord..."
supervisorctl start samba

echo "==> Waiting for Samba to start..."
sleep 3

echo "==> Verifying domain..."
samba-tool domain info 127.0.0.1

echo ""
echo "=============================="
echo " Domain provisioned successfully!"
echo " Realm:    ${REALM}"
echo " Domain:   ${DOMAIN}"
echo " Admin:    Administrator / ${ADMIN_PASS}"
echo "=============================="
