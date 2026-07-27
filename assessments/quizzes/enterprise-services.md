# Topic Quiz — DHCP, DNS, and Enterprise Services

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `enterprise-services-infra` and `dhcp-dns-troubleshooting`.

## Section 1 — Mechanisms (6 points)

### A1 — DHCP across a routed boundary (3 points)

Explain why a client broadcast needs a relay, what relay information lets the server
select the correct scope, and why a successful address lease does not prove the gateway
or DNS options are correct. (3 pts)

### A2 — DNS roles and dependencies (3 points)

Distinguish recursive resolution, authoritative data, and the resolver address delivered
to a client. State one symptom produced by failure at each boundary. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The lease works and names do not

```text
client address: 10.40.10.27/24
default route: via 10.40.10.1
/etc/resolv.conf: nameserver 192.0.2.53
ping 10.40.20.80: success
dig @10.40.99.53 app.internal.example A: 10.40.20.80
dig app.internal.example A: timeout
```

1. Identify what DHCP and DNS evidence proves. (3 pts)
2. Localize the fault and give the minimum correction. (2 pts)
3. Explain why changing the DNS server alone may not repair existing clients. (1 pt)
4. Give two post-change checks from the client perspective. (2 pts)

## Section 3 — Application (10 points)

### C1 — Design centralized branch services

Design DHCP, DNS, NTP, and syslog service delivery for three user VLANs behind routed
gateways. Include relay/scopes, service reachability, redundancy, time/logging source
identity, access restrictions, and positive plus negative verification. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — No lease after a VLAN migration

A user VLAN moves to a new gateway. Clients send DISCOVER but receive no OFFER. Give an
ordered evidence method across client, gateway/relay, routed path, server scope, and
return delivery. Name the relay or scope mistake most likely after the move. (6 pts)

*Key: [`../answer-keys/quizzes/enterprise-services-key.md`](../answer-keys/quizzes/enterprise-services-key.md).*
