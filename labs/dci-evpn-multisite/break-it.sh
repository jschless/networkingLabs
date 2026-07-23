#!/usr/bin/env bash
# Make Site B receive the inter-site EVPN NLRI but reject it from the PROD VRF.
set -euo pipefail

docker exec clab-dci-evpn-multisite-b-leaf Cli -p 15 -c $'enable\nconfigure\nrouter bgp 65021\nvrf PROD\nno route-target import evpn 65010:50010\nroute-target import evpn 65010:59999\nend' >/dev/null
echo 'Break-It injected: Site B has the type-5 NLRI but the PROD import RT is wrong.'
