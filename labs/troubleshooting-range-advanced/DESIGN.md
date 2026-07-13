# Advanced Range Design

**Topology version:** `2.0.0-draft`

This range is separate from `troubleshooting-range` so BGP, NAT, and PMTUD have
explicit golden-state assertions rather than becoming incidental mutations in
the single-area OSPF range.

The topology uses six lightweight FRR routers and three Linux endpoints. AS
65000 uses ISP1 as its preferred external path through local preference 200;
edge2 receives that path through iBGP and retains ISP2 as a usable fallback.
The core receives the internet prefix through OSPF with metrics 10 and 100. NAT is runtime state
restored by edge golden scripts. A 1400-byte edge1/core link creates a normal,
observable PMTUD dependency while all other data interfaces use MTU 1500.
