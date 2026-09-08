# dmvpn-ceos — Retired Redirect

This directory is intentionally **retired and non-runnable**. The old cEOS topology,
checker, and startup configurations were removed because they formed an unsupported
duplicate of the maintained VyOS DMVPN curriculum.

Use the active progression instead:

- [dmvpn-phase1](../dmvpn-phase1/README.md) builds hub-transit mGRE/NHRP forwarding.
- [dmvpn-phase2](../dmvpn-phase2/README.md) observes the current-image direct-path
  compatibility boundary.
- [dmvpn-phase3](../dmvpn-phase3/README.md) builds shortcut optimization and hub-owned
  service summarization.
- [dmvpn-phase3-ipsec-capstone](../dmvpn-phase3-ipsec-capstone/README.md) adds x509 IPsec
  protection in a capstone workflow.
- [debug-dmvpn-phase1](../debug-dmvpn-phase1/README.md) provides a guided Phase 1
  troubleshooting incident.

Arista cEOS remains in use where its locally validated features match a lab, but this
directory has no deployable topology.
