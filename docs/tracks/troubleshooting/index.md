# Troubleshooting & Assessment

This track separates deliberate troubleshooting practice from the technology
labs used to learn configuration. It offers two formats with different levels
of support and assessment pressure.

## Guided Debug Labs

The 15 [guided debug labs](../debug/index.md) each contain one intentional
fault, observable symptoms, three levels of hints, and a documented solution.
Use these to develop a repeatable evidence-gathering workflow before attempting
blind incidents.

## Proctored Assessment Ranges

The assessment ranges provide only a helpdesk-style ticket. They use persistent
topologies, transcript capture, weighted proctor rubrics, end-to-end verifiers,
and no-restart golden-state reset.

| Range | Tickets | Focus | Suggested readiness |
|---|---:|---|---|
| [Enterprise Troubleshooting Range](troubleshooting-range.md) | 24 | Access, addressing, OSPF, forwarding, DNS, TCP, and service policy | After the core routing and Operations labs |
| [Advanced Edge Troubleshooting Range](troubleshooting-range-advanced.md) | 8 | eBGP, iBGP, containment, redistribution, NAT, and PMTUD | After BGP, route control, and enterprise-edge labs |
| [Campus Troubleshooting Range](troubleshooting-range-campus.md) | 4 | STP, LACP, VLAN forwarding, and protected access ports | After Layer 2 campus and access-security labs |
| [Hybrid Access Troubleshooting Range](troubleshooting-range-hybrid-access.md) | 2 installed / 12 planned | Dual stack, hybrid transit, cloud policy, identity PEP, DNS, and application delivery | After cloud, zero-trust, dual-stack, WAN-overlay, and application-delivery labs |
| [DCI Edge Troubleshooting Range](troubleshooting-range-dci-edge.md) | 2 installed / 12 planned | Routed EVPN DCI, carrier QinQ, peering, storage paths, and inspected edge | After DCI, carrier, peering, storage, and advanced-security labs |

## Written Assessments

The ranges test whether you can repair a live network. The
[written assessment bank](../../assessments/index.md) tests the reasoning behind it —
five closed-book exams and 44 topic quizzes, on paper, against topologies you have not
seen. Section 5 of every exam is a troubleshooting narrative graded on method rather
than on landing the right answer.

## Recommended Progression

1. Complete guided debug labs in the protocols you are studying.
2. Attempt the enterprise range without reading scenario rubrics.
3. Review evidence quality and repeat weak diagnostic domains.
4. Attempt the advanced edge range under the published time limits.
5. Attempt the hybrid access reference tickets; its remaining catalog rows are
   not yet implemented.
6. Attempt the DCI edge reference tickets; its remaining catalog rows are also
   explicit placeholders.

The five ranges currently provide 40 installed blind tickets across T1, T2,
and T3 diagnostic-distance tiers. The hybrid access and DCI edge ranges each
list ten additional planned tickets explicitly as incomplete.
