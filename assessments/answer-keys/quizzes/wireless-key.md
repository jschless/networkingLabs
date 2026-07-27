# Answer Key — Enterprise Wireless Operations Topic Quiz

**Total:** 30 points

## A1 — Where client traffic enters the wired network (3 points)

- In a controller-tunneled design, AP client traffic is encapsulated to the controller
  and enters VLAN/policy at the controller-side boundary. This centralizes policy and can
  preserve an anchor during roaming, but makes controller/tunnel reachability a traffic
  dependency and concentrates failure domains. (1)
- In a locally bridged design, the AP decapsulates/bridges client traffic onto its local
  wired VLAN, so that VLAN and policy must exist at the AP access site. It reduces
  backhaul but expands distributed VLAN/policy consistency requirements. (1)
- Full credit requires a valid roaming tradeoff: IP, gateway, and security/session state
  must remain usable, or the roam becomes a readdress/reconnect event. (1)

## A2 — Identity is not the final policy (3 points)

- The supplicant first validates the EAP server certificate/trust and completes EAP-TLS;
  RADIUS then authenticates the identity. (1)
- Access-Accept attributes express an authorization result such as role or VLAN, which
  the authenticator/controller must successfully project into live port/session state.
  (1)
- Correct VLAN and downstream firewall/service policy must still be verified. An
  Access-Accept alone proves neither applied role nor permitted application reachability.
  (1)

## B1 — Guest works while corporate cannot join (8 points)

1. The corporate supplicant rejects the RADIUS server name during TLS, before successful
   EAP and Access-Accept. Guest forwarding proves the common guest data path remains
   usable; it does not exercise corporate EAP-TLS or its VLAN. (3)
2. Do not remove CA validation or `domain_suffix_match`, and do not tell the client to
   accept any server certificate. (1)
3. Restore a CA-valid RADIUS certificate whose identity matches
   `radius.branch.example`. Then prove: client EAP success with server validation;
   RADIUS Access-Accept and intended role/VLAN attribute; authenticator live corporate
   VLAN assignment; and permitted corporate service plus negative guest/quarantine
   isolation. (4)

## C1 — Design three wireless policy products (10 points)

- Carry an isolated AP-management VLAN on the AP uplink and restrict it to controller,
  RADIUS, DNS/NTP, and administration dependencies. (2)
- Map corporate, guest, and quarantine SSIDs/roles to separate segments; in local
  bridging those VLANs traverse the AP trunk, while tunneled designs terminate them at
  the controller boundary. (2)
- Use EAP-TLS/RADIUS for corporate identity and return explicit role/VLAN authorization;
  failed or remediation identities receive quarantine rather than corporate access. (2)
- Enforce distinct firewall products: corporate to approved internal services, guest to
  Internet only, and quarantine only to remediation/identity services. (2)
- Verify controller/RADIUS management reachability, authorization-to-VLAN state, and
  positive plus cross-segment negative tests for all three roles. (2)

## D1 — Do not turn a wired fixture into an RF claim (6 points)

- Correlate attempt timestamps across client association/roam events, EAP state, RADIUS,
  controller/AP logs, and wired VLAN/service state. (2)
- Gather real radio evidence: per-AP/channel utilization, RSSI/SNR over time, retry rates,
  neighboring AP candidates, client roam decisions, and 802.11k/v/r events or packet
  captures. Compare another client at the same location. (2)
- High utilization supports a capacity hypothesis but does not alone prove the roam
  cause; successful EAP/VLAN state narrows identity and wired-policy faults without
  eliminating transient controller or RF issues. (1)
- The labs prove live EAP-TLS, RADIUS, VLAN projection, and wired policy. Their synthetic
  RF records can teach interpretation but cannot claim a real association, roam, channel,
  RSSI, or site-survey measurement. (1)

## Remediation

| Weak area | Review |
|---|---|
| AP/controller placement, trunks, SSID-to-segment design, and failure domains | `labs/enterprise-wireless-architecture/` |
| EAP-TLS trust, RADIUS authorization, VLAN projection, and evidence limits | `labs/wireless-auth-control-operations/` |
