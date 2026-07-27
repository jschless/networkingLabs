# Answer Key — VRFs and Routed Segmentation Topic Quiz

**Total:** 30 points

## A1 — Separate tables, shared hardware (3 points)

- Each routed interface belongs to one VRF, and packets arriving there perform lookup in
  that VRF's independent RIB/FIB rather than the global or another tenant table. (1)
- Separate tables allow overlapping prefixes because identical destinations are resolved
  inside different VRF contexts. (1)
- On EOS, assigning the VRF after an IP address removes that address; configure the VRF
  first and then reapply addressing. (1)

## A2 — Controlled communication (3 points)

- Placing an interface or route in the wrong VRF unintentionally changes the lookup
  domain and can collapse isolation. (1)
- An intentional leak imports only approved reachability, with an auditable policy and
  next-hop resolution into the source VRF. (1)
- Applications still require return reachability and security policy/state; one leaked
  destination prefix creates only the forward lookup. (1)

## B1 — The shared service has no reply (8 points)

1. The BLUE route proves `pe1` can resolve the service destination through RED. It does
   not prove RED has a route back to the BLUE client, that firewalls permit the flow, or
   that the service uses the expected gateway. (2)
2. RED lacks return reachability to `10.20.60.0/24`, so replies follow an unusable
   default or are dropped. (2)
3. Leak only the required BLUE client/source prefix back into RED and enforce the exact
   service/port policy, or use a deliberately placed proxy/NAT boundary that supplies a
   controlled return path. Do not merge the routing tables. (2)
4. Prove the permitted client reaches the service bidirectionally, then test unrelated
   RED/BLUE client prefixes and prohibited ports to confirm isolation remains. (2)

## C1 — Design shared services for three tenants (10 points)

- Place DNS in a dedicated shared-services VRF or proxy boundary rather than one tenant's
  unrestricted table. (2)
- Import/leak only the DNS service host prefix into each tenant; do not import tenant
  aggregates or defaults into one another. (2)
- Supply explicit return reachability for each tenant source or use per-tenant
  proxy/NAT/service interfaces that preserve the originating context. (2)
- Enforce UDP/TCP 53 and approved sources at the shared boundary, with default deny and
  useful logging. (1)
- If tenant prefixes overlap, a single shared return table cannot distinguish identical
  destinations. Preserve VRF context through separate interfaces/instances or translate
  to unique source space. (2)
- Verify allowed DNS from every VRF plus negative cross-tenant, non-DNS, and transit
  tests while inspecting each VRF's routes and policy counters. (1)

## D1 — A black core learned a red route (6 points)

- The overlay/service prefix was redistributed or advertised into the underlay, violating
  the rule that the black core knows only transport reachability. This exposes topology
  and may create an unintended plaintext path. (2)
- Remove the leaked underlay advertisement and apply an explicit export filter that
  permits only encryptor transport endpoint/link prefixes; retain the red prefix solely
  in the overlay routing process. (2)
- Verify no core RIB/LSDB contains `10.40.0.0/16`, transport endpoints remain reachable,
  and the red overlay still carries the service route end to end. A core capture after
  IPsec should show only the expected outer transport/IKE/ESP, while red-side captures
  show the plaintext application. (2)

## Remediation

| Weak area | Review |
|---|---|
| Per-VRF routing, interface order, isolation, and route leaking | `labs/vrf-lite/` |
| Underlay/overlay separation and black-core evidence | `labs/black-core-routing/` |
