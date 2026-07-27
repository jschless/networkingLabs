# Answer Key — DHCP, DNS, and Enterprise Services Topic Quiz

**Total:** 30 points

## A1 — DHCP across a routed boundary (3 points)

- A client's initial DHCP broadcast does not cross a routed gateway, so the gateway relay
  forwards it as unicast to the server. (1)
- The relay supplies the client-subnet context, commonly `giaddr` or equivalent relay
  information, so the server selects the matching scope and returns the offer through
  the relay. (1)
- A lease includes independent options such as address, mask, router, and DNS. Correct
  addressing does not validate the other option values. (1)

## A2 — DNS roles and dependencies (3 points)

- A client sends queries to its configured recursive resolver; a wrong/unreachable
  resolver produces timeout or immediate reachability symptoms. (1)
- The recursive resolver follows/cache-resolves referrals or forwards queries; a failure
  here can affect broad external resolution while locally authoritative data still works.
  (1)
- An authoritative server owns the zone records; missing/wrong records affect particular
  names even when recursion and the resolver service are healthy. (1)

## B1 — The lease works and names do not (8 points)

1. DHCP supplied a usable address and gateway, and IP routing to the application works.
   The intended DNS server answers the name correctly when queried directly. The client
   default resolver path times out. (3)
2. DHCP option 6 points clients at invalid `192.0.2.53`; change the relevant scope to
   `10.40.99.53`. (2)
3. Existing clients retain lease options until renewal/rebind or manual resolver update,
   so a server-side option change is not immediately present on every endpoint. (1)
4. Renew the lease and verify resolver configuration now names `10.40.99.53`, then query
   normally without `@server` and reach the returned application address. (2)

## C1 — Design centralized branch services (10 points)

- Configure a relay on each user SVI and a distinct server scope matching that VLAN's
  subnet, router, DNS, lease policy, and exclusions. (2)
- Provide redundant DHCP/DNS endpoints or an explicit failover design with routed
  reachability and controlled helper targets. (2)
- Separate recursive and authoritative behavior as required, restrict recursion and
  zone transfers to approved clients, and monitor answer correctness. (2)
- Configure devices with authenticated/restricted NTP and centralized syslog using
  stable source addresses; correct time is required for trustworthy logs and security
  protocols. (2)
- Verify DORA/lease contents and forward/reverse DNS from each VLAN, time/log arrival
  with correct source/timestamp, plus negative unauthorized recursion/service access.
  (2)

## D1 — No lease after a VLAN migration (6 points)

Award 1 point for each boundary:

1. Capture the client's DISCOVER on the new VLAN and verify access VLAN/link state.
2. Confirm the new SVI receives it and has the intended helper/relay configuration.
3. Inspect the relayed request and subnet identifier/`giaddr`, then routed reachability
   to the server and back.
4. Verify the server has an active, non-exhausted scope matching the new relay subnet and
   logs the request.
5. Trace OFFER/ACK back to the relay and client, checking ACL/snooping policy.
6. The most likely migration defects are a helper left on the old SVI or a missing/wrong
   scope for the new relay subnet; repair that exact boundary and re-run full DORA.

## Remediation

| Weak area | Review |
|---|---|
| Central relay, DNS/NTP/syslog placement, and management dependencies | `labs/enterprise-services-infra/` |
| Lease-option and resolver troubleshooting | `labs/dhcp-dns-troubleshooting/` |
