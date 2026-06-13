#!/bin/bash
# ============================================================
# Capstone dc1 post-provision hook (mounted over the samba-ad-wazuh image's
# own hook). Runs on every boot via the samba-ad entrypoint, BEFORE samba
# starts, so it operates on the local sam.ldb offline. Must be idempotent.
#
# Two jobs:
#   1. Enable Samba structured (JSON) audit logging — same as the Lab 14
#      image hook (the Wazuh agent tails /var/log/samba/samba.log).
#   2. Mail-enable the foundation users (alice/bob/charlie) so the AD-backed
#      mail server has live mailboxes on boot. Part A mail-enables Dave the
#      same way (samba-tool user edit).
# ============================================================
set -e

SMB_CONF=/etc/samba/smb.conf
[ -f "$SMB_CONF" ] || exit 0

# --- 1. Samba JSON audit logging (Lab 14) ----------------------------------
if ! grep -q auth_json_audit "$SMB_CONF"; then
    sed -i '/^\[global\]/a\
\t# Capstone: structured security audit logging (tailed by the Wazuh agent)\
\tlogging = file\
\tlog file = /var/log/samba/samba.log\
\tlog level = 1 auth_audit:3 auth_json_audit:3 dsdb_audit:5 dsdb_json_audit:5' "$SMB_CONF"
    echo "==> [hook] Samba audit logging enabled"
fi
mkdir -p /var/log/samba

# --- 2. Mail-enable the foundation users -----------------------------------
# samba-tool has no setattr; drive `user edit` with a scripted EDITOR that
# appends mail: <sAMAccountName>@lab.corp when absent.
cat > /usr/local/bin/mail-enable-editor <<'EOF'
#!/bin/bash
f="$1"
grep -qi "^mail:" "$f" && exit 0
sam=$(sed -n "s/^sAMAccountName: //Ip" "$f" | head -1)
[ -n "$sam" ] || exit 0
content=$(sed -e :a -e "/^[[:space:]]*$/{\$d;N;ba}" "$f")
printf "%s\nmail: %s@lab.corp\n" "$content" "$sam" > "$f"
EOF
chmod +x /usr/local/bin/mail-enable-editor

# Only attempt once the domain is provisioned (users exist).
if [ -f /var/lib/samba/private/sam.ldb ]; then
    for u in alice bob charlie; do
        if samba-tool user show "$u" >/dev/null 2>&1; then
            EDITOR=/usr/local/bin/mail-enable-editor samba-tool user edit "$u" >/dev/null 2>&1 || true
        fi
    done
    echo "==> [hook] foundation users mail-enabled"
fi

# --- 3. Enroll the Wazuh agent (best-effort, background) -------------------
# The samba-ad-wazuh image ships the agent installed but unconfigured. Point it
# at the manager, add the JSON audit log as a source, enroll, start. Backgrounded
# and retried because the manager may still be coming up; the DC stays usable
# either way. Idempotent: skip if a key already exists.
WAZUH_MANAGER="10.100.3.30"
OSSEC=/var/ossec/etc/ossec.conf
if [ -f "$OSSEC" ]; then
    sed -i "s/MANAGER_IP/${WAZUH_MANAGER}/" "$OSSEC" 2>/dev/null || true
    # Ship the Samba JSON audit log if not already a localfile source.
    if ! grep -q "/var/log/samba/samba.log" "$OSSEC"; then
        sed -i "s#</ossec_config>#  <localfile>\n    <log_format>json</log_format>\n    <location>/var/log/samba/samba.log</location>\n  </localfile>\n</ossec_config>#" "$OSSEC" 2>/dev/null || true
    fi
    (
        for i in $(seq 1 40); do
            if [ -s /var/ossec/etc/client.keys ]; then break; fi
            if /var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" >/dev/null 2>&1; then
                /var/ossec/bin/wazuh-control restart >/dev/null 2>&1 || true
                echo "==> [hook] Wazuh agent enrolled"; break
            fi
            sleep 5
        done
    ) &
fi
