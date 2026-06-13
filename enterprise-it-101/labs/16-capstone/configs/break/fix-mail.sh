#!/bin/bash
# Part B, Break #3 — mail/LDAP repair. Run INSIDE mail1:
#   docker exec mail1 bash /break/fix-mail.sh
set -e
sed -i 's/^dnpass = .*/dnpass = P@ssw0rd1/' /etc/dovecot/dovecot-ldap.conf.ext
sed -i 's/^bind_pw = .*/bind_pw = P@ssw0rd1/' /etc/postfix/ldap-*.cf 2>/dev/null || true
doveadm reload 2>/dev/null || true
postfix reload 2>/dev/null || true
echo "[fix-mail] LDAP bind password restored to P@ssw0rd1 on Postfix + Dovecot."
