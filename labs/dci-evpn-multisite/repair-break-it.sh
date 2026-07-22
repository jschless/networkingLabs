#!/usr/bin/env bash
set -euo pipefail

docker exec clab-dci-evpn-multisite-b-leaf Cli -p 15 -c $'enable\nconfigure\nrouter bgp 65021\nvrf PROD\nno route-target import evpn 65010:59999\nroute-target import evpn 65010:50010\nend' >/dev/null
echo 'Repair applied: Site B imports Site A PROD RT 65010:50010 again.'
