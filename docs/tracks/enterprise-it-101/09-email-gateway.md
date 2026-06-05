---
title: "09 Email Gateway"
---

!!! tip "Practice Lab"
    Stand up a Postfix + Dovecot mail server backed by AD over LDAP (mailboxes and logins come from the directory), add MX, prove TLS by reading a password off the wire, sign mail with DKIM, catch spam, and diagnose a broken LDAP bind

!!! note "Platform"
    Docker Compose — `docker-mailserver` (registry image) + custom `samba-ad:local` and `workstation:local` images

{%
  include-markdown "../../../enterprise-it-101/labs/09-email-gateway/README.md"
%}
