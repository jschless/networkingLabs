#!/bin/bash
# Part B, Break #3 — mail/LDAP. Run INSIDE mail1:
#   docker exec mail1 bash /break/break-mail.sh
#
# Changes the LDAP bind password the mail server uses to look users up in AD.
# Postfix can no longer find recipients and Dovecot can no longer authenticate
# IMAP logins — the symptom is "mail clients suddenly can't log in", and the
# cause is only visible in the mail log (LDAP bind: Invalid credentials).
set -e
sed -i 's/^dnpass = .*/dnpass = WrongP@ss/' /etc/dovecot/dovecot-ldap.conf.ext
sed -i 's/^bind_pw = .*/bind_pw = WrongP@ss/' /etc/postfix/ldap-*.cf 2>/dev/null || true
doveadm reload 2>/dev/null || true
postfix reload 2>/dev/null || true
echo "[break-mail] LDAP bind password corrupted on Postfix + Dovecot."
echo "[break-mail] Symptom: IMAP logins fail; mail.log shows 'binding failed ... Invalid credentials'."
