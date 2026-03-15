#!/usr/bin/env bash
# dmvpn-ceos: Arista EOS does not support 'ip nhrp' on tunnel interfaces.
# This lab cannot be validated — NHRP configuration is not available in EOS 4.35.2F.
# Use dmvpn-phase1 (Linux/FRR with nhrpd) instead.
echo "ERROR: dmvpn-ceos uses Arista cEOS which does not support 'ip nhrp' on tunnel interfaces."
echo "       DMVPN cannot be configured on this platform."
echo "       Use labs/dmvpn-phase1 (Linux/FRR) for DMVPN practice."
exit 2
