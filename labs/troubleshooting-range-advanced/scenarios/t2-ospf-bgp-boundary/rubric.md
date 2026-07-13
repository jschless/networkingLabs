# Proctor rubric — AR-204

**Root cause:** edge1 is missing `redistribute bgp metric 10 route-map INTERNET-ONLY` under OSPF, so the core uses edge2's metric-100 external route. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms client service works over the backup edge | 10 | -5 if a total outage is assumed |
| Proves edge1 has the preferred BGP route while core uses edge2 | 30 | -15 if only one routing domain is inspected |
| Identifies the missing controlled redistribution statement | 25 | -10 if a static core route is proposed |
| Restores only the prefix-filtered metric-10 redistribution | 20 | -20 for unrestricted BGP redistribution |
| Verifies core next hop, route type, and client service | 15 | -10 if only the edge RIB is checked |

Static routes, redistributing all BGP prefixes, or altering edge2 metric caps the score at 69. The verifier is required for a pass.
