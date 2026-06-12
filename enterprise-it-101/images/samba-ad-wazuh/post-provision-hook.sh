#!/bin/bash
# Enable Samba's structured (JSON) security audit logging — the "pre-built"
# half of Lab 14. auth_json_audit logs every authentication attempt (Kerberos
# AS-REQ, NTLM, LDAP binds) as one JSON object per event; dsdb_json_audit
# logs directory writes (user created, group modified, ...). The Wazuh agent
# the student configures in the lab tails /var/log/samba/samba.log.
#
# Runs on every boot via the samba-ad entrypoint hook; must stay idempotent.
set -e

SMB_CONF=/etc/samba/smb.conf

# Nothing to do until the domain is provisioned (never the case in Lab 14,
# where AUTO_PROVISION=true provisions before this hook runs).
[ -f "$SMB_CONF" ] || exit 0

if ! grep -q auth_json_audit "$SMB_CONF"; then
    sed -i '/^\[global\]/a\
\t# Lab 14: structured security audit logging (tailed by the Wazuh agent)\
\tlogging = file\
\tlog file = /var/log/samba/samba.log\
\tlog level = 1 auth_audit:3 auth_json_audit:3 dsdb_audit:5 dsdb_json_audit:5' "$SMB_CONF"
    echo "==> [post-provision-hook] Samba audit logging enabled (auth_json_audit, dsdb_json_audit)"
fi

mkdir -p /var/log/samba
