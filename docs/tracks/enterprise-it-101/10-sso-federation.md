---
title: "10 SSO & Federation"
---

!!! tip "Practice Lab"
    Run Keycloak as an OIDC identity provider, federate it to Active Directory (AD owns the password, Keycloak brokers it), log into a sample app via the Authorization-Code flow, read the AD groups out of the decoded token, enforce TOTP MFA, and break the federation to watch SSO collapse

!!! note "Platform"
    Docker Compose — Keycloak + PostgreSQL (registry images), a custom Flask OIDC app, and `samba-ad:local` / `workstation:local`

{%
  include-markdown "../../../enterprise-it-101/labs/10-sso-federation/README.md"
%}
