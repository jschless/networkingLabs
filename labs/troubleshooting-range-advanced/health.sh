#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
pass=0 fail=0
ok() { echo "  PASS $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1 -- $2"; fail=$((fail+1)); }
frr() { docker exec "$P-$1" vtysh -c "$2" 2>/dev/null; }
node() { docker exec "$P-$1" sh -lc "$2" 2>/dev/null; }
check_bgp() {
  local node_name="$1" peer="$2" out
  out="$(frr "$node_name" "show bgp neighbor $peer" || true)"
  if [[ "$out" == *'BGP state = Established'* ]]; then ok "$node_name BGP peer $peer Established"
  else bad "$node_name BGP peer $peer" "not Established"; fi
}
check_tcp() {
  local from="$1" path="$2"
  if node "$from" "python3 -c 'import socket; s=socket.create_connection((\"198.18.10.10\",8080),3); s.sendall(b\"GET $path HTTP/1.0\\r\\nHost: internet.test\\r\\n\\r\\n\"); data=b\"\"; exec(\"while True:\\n c=s.recv(8192)\\n if not c: break\\n data+=c\") ; print(len(data)); assert len(data)>100'" >/dev/null; then ok "$from fetches $path"
  else bad "$from fetches $path" "TCP/HTTP transfer failed"; fi
}

docker inspect "$P-core1" >/dev/null 2>&1 || { echo 'ERROR: advanced range is not deployed'; exit 2; }
echo '=== Advanced Troubleshooting Range health gate ==='
check_bgp edge1 192.0.2.1
check_bgp edge1 10.251.0.5
check_bgp edge2 192.0.2.3
check_bgp edge2 10.251.0.4
check_bgp isp1 192.0.2.5
check_bgp isp2 192.0.2.7

edge1_running="$(frr edge1 'show running-config' || true)"
if [[ "$edge1_running" != *'network 10.251.10.0/24'* && "$edge1_running" != *'maximum-prefix'* ]]; then
  ok 'edge1 has no private-prefix origination or stale prefix ceiling'
else
  bad 'edge1 BGP containment baseline' 'unexpected private network statement or maximum-prefix override'
fi

leaked_route="$(frr internet-core 'show bgp ipv4 unicast 10.251.10.0/24' || true)"
extra_provider_route="$(frr internet-core 'show bgp ipv4 unicast 203.0.113.0/24' || true)"
if [[ "$leaked_route" == *'not in table'* && "$extra_provider_route" == *'not in table'* ]]; then
  ok 'external BGP table contains only approved baseline prefixes'
else
  bad 'external BGP baseline' 'private leak or maintenance-only provider prefix remains'
fi

edge1_route="$(frr edge1 'show bgp ipv4 unicast 198.18.10.0/24' || true)"
[[ "$edge1_route" == *'192.0.2.1'* && "$edge1_route" == *'localpref 200'* ]] && ok 'edge1 prefers ISP1 at local preference 200' || bad 'edge1 internet path' 'ISP1/local-pref 200 is not selected'
edge2_route="$(frr edge2 'show bgp ipv4 unicast 198.18.10.0/24' || true)"
[[ "$edge2_route" == *'10.251.0.4'* && "$edge2_route" == *'localpref 200'* ]] && ok 'edge2 prefers the iBGP path through edge1' || bad 'edge2 internet path' 'preferred iBGP path is not selected'
internet_route="$(frr core1 'show ip route 198.18.10.0/24' || true)"
[[ "$internet_route" == *'10.251.0.1'* ]] && ok 'core internet prefix uses edge1' || bad 'core internet prefix' 'edge1 next hop missing'
node edge1 'iptables -t nat -C POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE' && ok 'edge1 NAT policy present' || bad 'edge1 NAT policy' 'MASQUERADE rule missing'
node edge2 'iptables -t nat -C POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE' && ok 'edge2 NAT policy present' || bad 'edge2 NAT policy' 'MASQUERADE rule missing'
node corp1 'ping -c 1 -W 2 198.18.10.10' >/dev/null && ok 'corporate reaches internet test server' || bad 'corporate internet reachability' 'ping failed'
node branch-client 'ping -c 1 -W 2 198.18.10.10' >/dev/null && ok 'branch reaches internet test server' || bad 'branch internet reachability' 'ping failed'
check_tcp corp1 /index.html
check_tcp corp1 /large.bin
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
