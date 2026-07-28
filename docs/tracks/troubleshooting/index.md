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

The three ranges currently provide 36 blind tickets across T1, T2, and T3
diagnostic-distance tiers.
