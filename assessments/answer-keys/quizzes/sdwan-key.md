# Answer Key — SD-WAN and Orchestrated Overlays Topic Quiz

**Total:** 30 points

## A1 — Separate the planes (3 points)

- The underlay provides reachability between transport endpoints; the encrypted overlay
  requires tunnel keys/handshakes and overlay routes. (1)
- The control plane authenticates edges and distributes desired policy/routes, while
  edge acknowledgement proves applied state rather than mere controller intent. (1)
- SLA probes measure the application path's loss/latency/jitter. An ISP ping can be green
  while tunnel identity, policy, overlay routing, segmentation, or application health is
  broken. (1)

## A2 — Application-aware path selection (3 points)

- Classify traffic by a reliable field/application and direct it to the corresponding
  policy table or centrally supplied path preference. (1)
- Measure loss, latency, and jitter over a window; move traffic only after the failure
  threshold, not one sample. Reachability-only probes miss excessive delay/loss while
  replies still arrive. (1)
- Require a stronger recovery threshold and/or hold-down before failback to prevent
  oscillation, and apply compatible policy in both directions. (1)

## B1 — Green transports, withdrawn private service (8 points)

1. Both underlays are healthy. Branch identity/control is rejected because its
   certificate is revoked; without trusted policy reconciliation the encrypted overlay
   has no recent handshake/route, so private service is withdrawn. (3)
2. SaaS uses local Internet breakout and does not require the private overlay. Underlay
   probes reach transport endpoints without proving mTLS enrollment, tunnel state, or
   private routes. (2)
3. Re-enroll/rotate only branch7's identity through the trusted PKI; do not bypass
   validation. Verify the new certificate and controller authentication/applied version,
   a recent WireGuard handshake plus restored private route, and CORP application
   reachability while GUEST remains denied. (3)

## C1 — Roll out policy without confusing intent and state (10 points)

- Validate and version policy 12, including explicit CORP permits/routes and GUEST
  non-leak assertions, before publication. (2)
- Publish to a small canary group and record desired version separately from each edge's
  fetched/applied acknowledgement. (2)
- Test overlay route state, CORP service, GUEST negative access, and local breakout from
  the canaries before expanding in bounded batches. (2)
- Stop on missing/stale acknowledgements, segmentation failures, tunnel loss, or service
  regression; preserve audit data and the last known-good edge state. (2)
- Roll controller intent back to the validated prior version, require rollback
  acknowledgements, and repeat operational verification. `desired_version=12` proves
  only controller intent, not edge application. (2)

## D1 — Tune a brownout response (6 points)

- Probe the relevant tunnel frequently enough to observe the service objective and
  calculate loss/latency/jitter over a multi-sample sliding window. (2)
- Declare failure only after a sustained threshold, such as several consecutive bad
  windows or the configured percentage, and require more good samples plus a hold-down
  for recovery. Exact defensible numbers may vary. (2)
- Verify timestamped probe state, selected policy-table route, and marked voice traffic
  capture/application quality during impairment and recovery. Test both directions or
  coordinated edges so one side does not select an incompatible path. Confirm no repeated
  path changes during isolated bad samples. (2)

## Remediation

| Weak area | Review |
|---|---|
| Underlay/overlay mapping, classification, probes, blackout, and brownout behavior | `labs/sdwan-concepts/` |
| PKI enrollment, controller acknowledgement, segmentation, SLA steering, and rollback | `labs/orchestrated-wan-overlay/` |
