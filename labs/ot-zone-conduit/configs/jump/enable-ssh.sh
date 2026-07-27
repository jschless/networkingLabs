#!/usr/bin/env bash
set -euo pipefail
id otmaint >/dev/null 2>&1 || useradd -m -s /bin/bash otmaint
printf 'otmaint:LAB-ONLY-enterprise-to-jump\n' | chpasswd
install -d -m 0755 /run/sshd /run/ot
cat >/run/ot/sshd_config <<'EOF'
Port 2222
ListenAddress 0.0.0.0
PasswordAuthentication yes
PermitRootLogin no
UsePAM no
PidFile /run/ot/sshd.pid
Subsystem sftp internal-sftp
EOF
if [[ -f /run/ot/sshd.pid ]]; then
  kill "$(cat /run/ot/sshd.pid)" 2>/dev/null || true
fi
/usr/sbin/sshd -f /run/ot/sshd_config -E /run/ot/ssh-auth.log
