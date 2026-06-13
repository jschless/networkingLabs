#!/bin/bash
# ============================================================
# Capstone workstation bootstrap.
#
# MODE=full  (admin-ws)  — an existing, fully-configured corp workstation:
#   domain-joined (adcli) + sssd identity/login + chrony time + Wazuh agent
#   enrolled. Used to run admin/verification commands against the live stack.
#
# MODE=client (ws-dave)  — the NEW employee's bare machine. Only chrony runs
#   (so Part A can verify NTP sync). Joining the domain, logging in, and
#   enrolling the Wazuh agent are PART A student tasks — do NOT pre-do them.
#
# Wazuh enrollment is best-effort: if the manager isn't up (e.g. you only
# started the core tier), the box still comes up joined.
# ============================================================
set -e

MODE="${MODE:-full}"
ADMIN_PASS="${ADMIN_PASS:-P@ssw0rd1}"
NTP_SERVER="10.100.1.20"
WAZUH_MANAGER="10.100.3.30"
DC="dc1.lab.corp"

# --- Time: point chrony at the lab NTP server and run it (both modes) -------
cat > /etc/chrony/chrony.conf <<EOF
server ${NTP_SERVER} iburst
driftfile /var/lib/chrony/chrony.drift
EOF
chronyd -x

if [ "$MODE" = "client" ]; then
    echo "==> [ws] client mode (bare new-employee machine): chrony only."
    exec sleep infinity
fi

# --- MODE=full: join the domain --------------------------------------------
echo "==> [ws] waiting for the DC's Kerberos KDC..."
for i in $(seq 1 60); do
    if getent hosts "$DC" >/dev/null 2>&1 && (echo > /dev/tcp/dc1.lab.corp/88) 2>/dev/null; then
        echo "==> [ws] DC reachable."; break
    fi
    sleep 2
done

echo "==> [ws] joining lab.corp..."
echo "${ADMIN_PASS}" | adcli join lab.corp -U Administrator --stdin-password || {
    echo "==> [ws] join failed; retrying once after 5s..."; sleep 5
    echo "${ADMIN_PASS}" | adcli join lab.corp -U Administrator --stdin-password
}

# --- sssd: identity + login from AD ----------------------------------------
cat > /etc/sssd/sssd.conf <<'EOF'
[sssd]
domains = lab.corp
config_file_version = 2
services = nss, pam

[domain/lab.corp]
id_provider = ad
auth_provider = ad
access_provider = ad
ad_domain = lab.corp
krb5_realm = LAB.CORP
cache_credentials = True
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = True
fallback_homedir = /home/%u@%d
ad_gpo_access_control = permissive
EOF
chmod 0600 /etc/sssd/sssd.conf

sed -i 's/^passwd:.*/passwd:         files sss/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:          files sss/'  /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:         files sss/' /etc/nsswitch.conf
DEBIAN_FRONTEND=noninteractive pam-auth-update --enable sss --enable mkhomedir >/dev/null 2>&1
pkill -x sssd 2>/dev/null || true
sleep 1
sssd

# A non-root local account for testing AD logins (root su skips passwords).
id tester >/dev/null 2>&1 || useradd -m -s /bin/bash tester

# --- Wazuh agent: enroll against the manager (best-effort) ------------------
(
    echo "==> [ws] enrolling Wazuh agent (best-effort)..."
    sed -i "s/MANAGER_IP/${WAZUH_MANAGER}/" /var/ossec/etc/ossec.conf 2>/dev/null || true
    for i in $(seq 1 30); do
        if /var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" >/dev/null 2>&1; then
            /var/ossec/bin/wazuh-control restart >/dev/null 2>&1 || true
            echo "==> [ws] Wazuh agent enrolled."; break
        fi
        sleep 5
    done
) &

echo "==> [ws] full workstation ready (joined + sssd + chrony + wazuh)."
exec sleep infinity
