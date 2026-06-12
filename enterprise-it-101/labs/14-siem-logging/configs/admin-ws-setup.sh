#!/bin/bash
# admin-ws bootstrap (GIVEN scaffolding): run rsyslog + an SSH server so that
# authentication events land in /var/log/auth.log in REAL syslog format
# (timestamp + hostname + program[pid]) — the format Wazuh's sshd decoder
# expects. Also create the weak local service account the intruder will
# brute-force.
set -e

# The target account. Weak on purpose — this is the lab's victim, and the
# brute force succeeds eventually so you can see "success after failures".
if ! id svc-backup >/dev/null 2>&1; then
    useradd -m -s /bin/bash svc-backup
    echo 'svc-backup:Summer2025' | chpasswd
fi

mkdir -p /run/sshd
ssh-keygen -A

cat > /etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
SyslogFacility AUTH
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# rsyslog turns sshd's AUTH-facility messages into properly-formatted
# /var/log/auth.log lines (the format the Wazuh sshd decoder matches).
# Drop imklog (no /proc/kmsg access in a container) and make auth.log
# writable by rsyslog's unprivileged 'syslog' user.
sed -i 's/^module(load="imklog".*/# imklog disabled in container/' /etc/rsyslog.conf
touch /var/log/auth.log
chown syslog:adm /var/log/auth.log
rsyslogd

# -D foreground only. NO -e: that would divert logs to stderr; we want them
# to go to syslog (the default) so rsyslog writes /var/log/auth.log.
exec /usr/sbin/sshd -D
