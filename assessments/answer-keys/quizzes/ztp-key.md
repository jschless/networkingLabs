# Answer Key — Zero-Touch Provisioning Topic Quiz

**Total:** 30 points

## A1 — Enter and complete ZTP (3 points)

- EOS enters ZTP only when neither `startup-config` nor `zerotouch-config` on flash marks
  the device as already owned/provisioned. (1)
- DHCP option 67 supplies the boot/config URI string that the ZTP client interprets and
  fetches. (1)
- Successful fetch/application, production verification, and creation of the resulting
  startup/done marker distinguish completion from a DHCP/fetch retry loop. (1)

## A2 — Bootstrap trust (3 points)

The first responder can redirect an unowned device to attacker-controlled configuration,
and plain HTTP supplies no server authenticity or content integrity. Award 1 point each
for three controls such as:

- isolated, access-controlled provisioning VLAN with DHCP snooping/known relay path;
- per-device inventory identity and allowlisted serial/MAC/claim workflow;
- HTTPS with validated trust or signed/hash-verified artifacts;
- short-lived enrollment credentials with no reusable fleet secret;
- pre-deployment template validation and immutable/versioned artifacts;
- audited DHCP/HTTP requests and one-time enrollment.

## B1 — A healthy DHCP loop that never provisions (8 points)

1. DHCP completes and supplies option 67, but the requested per-device artifact does not
   exist. HTTP 404 prevents configuration application, so the client schedules another
   ZTP cycle and never writes completion files. (3)
2. Publish the intended validated `branch-17.cfg` at the advertised path or correct
   option 67 to the existing intended artifact; let the next retry retrieve it. (2)
3. Observe HTTP GET 200 and switch fetch/apply completion; verify startup/completion
   markers plus intended hostname/banner/config; and test production forwarding from an
   affected endpoint. (3)

## C1 — Provision 400 unique switches safely (10 points)

- Maintain per-device intended identity/role/site in a source of truth and select content
  from a validated serial/MAC/enrollment claim rather than one shared config. (2)
- Restrict the provisioning segment and DHCP responders; authenticate the server and
  verify signed/hash-pinned, versioned artifacts. (2)
- Render and syntax/policy-test each device configuration before publication, including
  duplicate addressing and reachability checks. (2)
- Deliver only bootstrap necessities and short-lived enrollment credentials; retrieve
  long-term secrets through a protected post-bootstrap system. (1)
- Record device, offered URI, artifact version/hash, fetch, result, and operator/change
  provenance. (1)
- After management reachability and identity verification, hand ongoing configuration
  to the normal automation/source-of-truth workflow and prevent repeated ZTP ownership.
  Include canary rollout and rescue/rollback. (2)

## D1 — Config applied, branch still unreachable (6 points)

- Hostname/banner and completion files prove fetch/application; compare the delivered
  artifact and running config for production interfaces, `no switchport`, addressing,
  routing/default route, and service policy. (2)
- Test management separately from production links, then client gateway and routed
  server reachability. A missing production command is not repaired by restarting DHCP
  or deleting ZTP state blindly. (1)
- Correct/version the source artifact, validate it, and reprovision or apply the bounded
  delta through the supported automation path, then repeat identity and forwarding
  checks. (2)
- Preserve OOB/console, a known-good startup image/config, or timed rollback so a dark
  branch can recover when production reachability never comes up. (1)

## Remediation

| Weak area | Review |
|---|---|
| ZTP gates, DHCP/HTTP sequence, retry diagnosis, fleet trust, and handoff | `labs/ztp-basics/` |
