# Answer Key — Network Automation and Source of Truth Topic Quiz

**Total:** 30 points

## A1 — Failure layers in an API workflow (3 points)

1. Connection refused is a transport/service-listener failure: verify address, routing,
   port, and whether the API service is listening. (1)
2. HTTP 401 is an HTTP authentication failure before the command body is processed:
   verify credentials and authentication policy. (1)
3. HTTP 200 with a JSON-RPC error reached the application/API layer: inspect the method,
   command, parameters, and returned error. (1)

## A2 — Idempotence and closed-loop verification (3 points)

- API acceptance proves only that the target accepted a request; it does not prove the
  desired operational outcome or whether repeating the request is safe. (1)
- On the first run, read current structured state, calculate the necessary delta, apply
  only that delta, and verify the result from an independent or downstream vantage
  point. (1)
- On the second identical run, the read phase should find the desired state already
  present, make zero configuration changes, and still verify the intended outcome. (1)

## B1 — Green script, missing route (8 points)

1. The job checks only local configuration and local BGP origination. Its intended
   outcome is propagation and usable forwarding, which the remote evidence disproves.
   (2)
2. Award 1 point each for three relevant checks: the leaf-spine BGP session is
   Established; export policy permits the prefix; next-hop and AFI/SAFI are correct; the
   spine receives and selects the route; the spine installs it in the RIB/FIB; or a
   remote source can reach the loopback with a valid return path. (3)
3. Retry the independent checks for a bounded interval, then exit nonzero with captured
   evidence and either stop the rollout or invoke an explicitly designed rollback. Never
   wait forever or mark a timeout as PASS. (2)
4. The second identical run should make no configuration call because the intended
   configuration already exists. (1)

## C1 — Guard a source-of-truth rollout (10 points)

- Validate NetBox object relationships, uniqueness, prefix overlap, VLAN/interface
  constraints, and required fields before rendering. An overlap must stop here. (2)
- Render from the versioned source of truth and validate generated syntax/schema for
  every affected role. A bad shared template must fail CI before deployment. (2)
- Produce and review a semantic per-device diff, with the affected inventory and change
  intent recorded. (2)
- Back up current state and deploy to a canary or bounded batch before expanding scope.
  (1)
- Verify device acceptance plus VLAN/interface state and an independent end-to-end
  service path; stop on any failed gate. (2)
- Define recovery using the captured prior config or a known-good rendered version, then
  re-verify after rollback. (1)

Do not award full credit for a workflow that jumps directly from a NetBox edit to an
unbounded fleet push.

## D1 — Which side is authoritative? (6 points)

- Determine whether the manual change was approved incident intent or unauthorized
  drift, whether it is still required, and which state satisfies the current design and
  recovery objective. The decision belongs to the change/incident owner, not to whichever
  system ran last. (2)
- Preserve the before/after running config, facts, NetBox version, timestamps, operator
  identity, incident record, and observed traffic result before reconciling. (2)
- Use a safeguard such as report-only discovery, field-level ownership, a review/approval
  queue, versioned diffs, or an incident lock that prevents automatic write-back. (1)
- After choosing a direction, update the authoritative record and device deliberately,
  then rerun drift and operational verification so both datasets converge. (1)

## Remediation

| Weak area | Review |
|---|---|
| Structured APIs, failure layers, idempotence, and remote verification | `labs/automation-fundamentals/` |
| Modeled intent, rendering, discovery, and drift reconciliation | `labs/network-automation-netbox/` |
