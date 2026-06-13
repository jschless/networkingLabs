#!/bin/bash
# Runs at every docker-mailserver startup (GIVEN scaffolding).
#
# AD's LDAPS cert is self-signed and SAN-less, so relax verification for the
# LDAP lookups (Postfix + Dovecot). The channel is still encrypted (LDAPS).
for f in /etc/postfix/ldap-*.cf; do
  [ -f "$f" ] || continue
  sed -i '/^tls_require_cert/d' "$f"
  echo "tls_require_cert = no" >> "$f"
done
if [ -f /etc/dovecot/dovecot-ldap.conf.ext ]; then
  sed -i '/^tls_require_cert/d' /etc/dovecot/dovecot-ldap.conf.ext
  echo 'tls_require_cert = never' >> /etc/dovecot/dovecot-ldap.conf.ext
fi

# Treat the lab network as internal so OpenDKIM SIGNS our clients' outbound
# mail (OpenDKIM only signs mail from trusted/internal hosts).
if [ -f /etc/opendkim/TrustedHosts ] && ! grep -q "10.100.0.0/16" /etc/opendkim/TrustedHosts; then
  echo "10.100.0.0/16" >> /etc/opendkim/TrustedHosts
fi
