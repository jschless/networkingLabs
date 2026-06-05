#!/bin/bash
# ws1/ws2 bootstrap (GIVEN scaffolding): run an SSH server that trusts the
# Ansible control node's key, so ansible1 can manage this host. This is the
# plumbing the lab is *not* about — Ansible-over-SSH is the standard transport.
set -e

mkdir -p /run/sshd /root/.ssh
install -m 600 /lab/ansible_ed25519.pub /root/.ssh/authorized_keys
chmod 700 /root/.ssh

# Host keys for sshd.
ssh-keygen -A

# A deliberately permissive starting sshd config so the lab's hardening
# playbook (Part B) has something to tighten. Root login + password auth ON.
cat > /etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

exec /usr/sbin/sshd -D -e
