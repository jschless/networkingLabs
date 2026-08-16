#!/usr/bin/env bash
# Apply the complete healthy learned state. Re-running is safe.
set -euo pipefail

prefix=clab-gre-basics

for node in gw-a gw-b; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: gre-basics is not fully deployed" >&2
        exit 1
    }
done

docker exec -i "$prefix-gw-a" Cli -p 15 >/dev/null <<'EOS'
enable
configure
no ip route 192.168.2.0/24 172.16.0.2
no ip route 203.0.113.6/32 172.16.0.2
interface Tunnel0
   tunnel source interface Ethernet2
   tunnel destination 203.0.113.6
   ip address 172.16.0.1/30
   tunnel path-mtu-discovery
   tunnel ttl 255
   ip ospf area 0
   ip ospf network point-to-point
   no shutdown
interface Ethernet1
   ip ospf area 0
router ospf 1
   router-id 10.0.0.1
   passive-interface Ethernet1
   tunnel routes
end
EOS

docker exec -i "$prefix-gw-b" Cli -p 15 >/dev/null <<'EOS'
enable
configure
no ip route 192.168.1.0/24 172.16.0.1
interface Tunnel0
   tunnel source interface Ethernet1
   tunnel destination 203.0.113.1
   ip address 172.16.0.2/30
   tunnel path-mtu-discovery
   tunnel ttl 255
   ip ospf area 0
   ip ospf network point-to-point
   no shutdown
interface Ethernet2
   ip ospf area 0
router ospf 1
   router-id 10.0.0.2
   passive-interface Ethernet2
   tunnel routes
end
EOS

for _attempt in $(seq 1 50); do
    a_neighbor=$(docker exec "$prefix-gw-a" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    b_neighbor=$(docker exec "$prefix-gw-b" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    if grep -qE '10\.0\.0\.2.*[Ff][Uu][Ll][Ll]' <<<"$a_neighbor" \
        && grep -qE '10\.0\.0\.1.*[Ff][Uu][Ll][Ll]' <<<"$b_neighbor" \
        && docker exec "$prefix-host-a" ping -c 2 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 2 -W 1 192.168.1.10 >/dev/null 2>&1; then
        echo "Healthy end state applied. Run the checker to grade every mechanism."
        exit 0
    fi
    sleep 1
done

echo "ERROR: healthy end state did not converge within the bounded wait" >&2
exit 1
