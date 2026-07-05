#!/usr/bin/env bash
# Automated end-state assertions for the anycast-dns lab.
# Run via: ./scripts/lab.sh check anycast-dns
# (no pipefail: grep -q exiting early would SIGPIPE the producer and
# turn passing checks into flaky failures)
set -u

P=clab-anycast-dns
PASS=0
FAIL=0

ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# dig TXT whoami.lab.test against an address, from a client node
whoami_from() { # $1=client $2=server-addr
    docker exec "$P-$1" dig +time=2 +tries=1 +short @"$2" TXT whoami.lab.test 2>/dev/null | tr -d '"'
}

# retry a whoami until it returns the expected instance (BGP convergence)
wait_whoami() { # $1=client $2=addr $3=expected $4=max-seconds
    local waited=0
    while [ "$waited" -lt "$4" ]; do
        [ "$(whoami_from "$1" "$2")" = "$3" ] && return 0
        sleep 2; waited=$((waited + 2))
    done
    return 1
}

for node in r1 r2 dns1 dns2 c1 c2; do
    docker inspect "$P-$node" >/dev/null 2>&1 \
        && ok "$node container running" \
        || bad "$node container running"
done

# eBGP sessions Established (Tasks 2-3): r1 and r2 peer with each other + their server
for node in r1 r2; do
    est=$(docker exec "$P-$node" vtysh -c 'show bgp summary json' 2>/dev/null \
          | grep -c '"state":"Established"')
    if [ "$est" -eq 2 ]; then
        ok "$node has 2 Established BGP sessions"
    else
        bad "$node has 2 Established BGP sessions (saw $est)"
    fi
done

# Redistribution filter (Task 3): the clab mgmt subnet must NOT be in BGP
if docker exec "$P-r1" vtysh -c 'show bgp ipv4 unicast 172.20.20.0/24' 2>/dev/null \
     | grep -q 'Network not in table'; then
    ok "mgmt subnet 172.20.20.0/24 not leaked into BGP (route-map filter)"
else
    bad "mgmt subnet 172.20.20.0/24 not leaked into BGP (unfiltered redistribute connected?)"
fi

# r1 sees both paths to the VIP (direct + via r2)
paths=$(docker exec "$P-r1" vtysh -c 'show bgp ipv4 unicast 10.53.53.53/32' 2>/dev/null \
        | grep -c '^  65')
if [ "$paths" -eq 2 ]; then
    ok "r1 holds 2 BGP paths to the VIP"
else
    bad "r1 holds 2 BGP paths to the VIP (saw $paths)"
fi

# Closest-instance selection (Task 4)
[ "$(whoami_from c1 10.53.53.53)" = "dns1" ] \
    && ok "c1 anycast query answered by dns1 (closest)" \
    || bad "c1 anycast query answered by dns1 (closest)"
[ "$(whoami_from c2 10.53.53.53)" = "dns2" ] \
    && ok "c2 anycast query answered by dns2 (closest)" \
    || bad "c2 anycast query answered by dns2 (closest)"

# Both instances serve the same data
a=$(docker exec "$P-c1" dig +time=2 +tries=1 +short @10.53.53.53 www.lab.test 2>/dev/null)
[ "$a" = "192.0.2.80" ] \
    && ok "www.lab.test resolves via the VIP (got $a)" \
    || bad "www.lab.test resolves via the VIP (got ${a:-nothing})"

# Unique instance addresses stay reachable (how you monitor ONE instance)
[ "$(whoami_from c2 10.0.0.11)" = "dns1" ] \
    && ok "dns1 unique address 10.0.0.11 answers from the far site" \
    || bad "dns1 unique address 10.0.0.11 answers from the far site"

# Anycast is 2 hops from c1: r1 then the VIP (terminates at dns1)
hops=$(docker exec "$P-c1" traceroute -n -q 1 -w 1 10.53.53.53 2>/dev/null \
       | grep -c '^ *[0-9]')
if [ "$hops" -eq 2 ]; then
    ok "c1 traceroute to VIP is 2 hops (local instance)"
else
    bad "c1 traceroute to VIP is 2 hops (saw $hops)"
fi

# Failover (Tasks 5-6): kill dnsmasq on dns1 -> watchdog withdraws the VIP
# -> c1 is transparently served by dns2; then restore and converge back.
docker exec "$P-dns1" pkill dnsmasq >/dev/null 2>&1
if wait_whoami c1 10.53.53.53 dns2 20; then
    ok "failover: dns1 service death moves c1 to dns2"
else
    bad "failover: dns1 service death moves c1 to dns2"
fi
docker exec "$P-dns1" dnsmasq >/dev/null 2>&1
if wait_whoami c1 10.53.53.53 dns1 20; then
    ok "recovery: dnsmasq restart brings c1 back to dns1"
else
    bad "recovery: dnsmasq restart brings c1 back to dns1"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
