# Answer Key — BGP Labeled Unicast Topic Quiz

**Total:** 30 points

## A1 — Signal a labeled prefix (3 points)

- The labeled-unicast AF advertises prefix reachability together with an MPLS label,
  allowing BGP to build a labeled path where an IGP label protocol does not cross the AS
  boundary. (2)
- Every router allocates labels from its own local space and advertises its binding;
  neighbors program swaps, so numeric labels need not match end to end. (1)

## A2 — Underlay and session choices (3 points)

- Loopback iBGP depends on the intra-AS IGP to reach both loopback TCP endpoints and
  resolve next hops, gaining resilience across internal links. (2)
- Adjacent ASBRs normally peer eBGP-LU on their directly connected addresses because no
  shared IGP makes remote loopbacks reachable across the boundary. (1)

## B1 — The label stitch disappeared (8 points)

1. Ordinary IPv4 reachability and TCP session state survive, but the remote prefix is not
   present in the labeled-unicast AF, so no label binding reaches r2/LFIB and the
   end-to-end LSP breaks. (3)
2. Likely causes include the neighbor not activated in `ipv4 labeled-unicast`, AF-specific
   policy denying the prefix, or the ASBR failing to advertise/re-advertise it in that
   AF. (2)
3. Verify LU neighbor/prefix/label on each control-plane hop, LFIB in-label/out-label/next
   hop at both ASBRs, and sourced end-to-end reachability or a labeled capture after
   repair. (3)

## C1 — Trace the label chain (10 points)

- r4 originates its loopback with label 17; its local forwarding terminates the FEC.
  (2)
- r3 receives label 17, allocates local label 28, advertises 28 to r2, and programs
  incoming 28 toward outgoing 17/next hop r4 as appropriate. (2)
- r2 receives 28, allocates label 39, advertises 39 to r1, and programs incoming 39 to
  outgoing 28/next hop r3. (2)
- r1 associates remote FEC 10.0.0.4/32 with the label learned from r2 and pushes 39.
  Transit nodes swap according to their own LFIB; PHP may remove the final transport
  label where signaled. (2)
- Full credit requires distinguishing BGP advertised labels from local incoming labels
  and verifying BGP-LU plus LFIB rather than inferring from a successful IP ping. (2)

## D1 — Choose inter-AS Option C (6 points)

- Option C avoids per-VRF ASBR handoffs and scales VPN endpoint transport through labeled
  reachability, reducing service-specific ASBR configuration. (2)
- It expands BGP/LU and LFIB state, shares reachability/policy trust across providers, and
  makes AF/policy/label failures capable of affecting many VPNs. (2)
- Use strict prefix/label policy, maximums, authentication/monitoring, independent
  control-plane and LFIB checks, and end-to-end service probes. Prefer simpler Option-A
  style handoffs where tenant count is small or administrative trust/isolation outweighs
  scale. (2)

## Remediation

| Weak area | Review |
|---|---|
| BGP-LU address family, local label stitching, LFIB, and Inter-AS Option C | `labs/bgp-labeled-unicast/` |
