#!/usr/bin/env bash
# Automated end-state assertions for the k8s-fabric lab.
# Run via: ./scripts/lab.sh check k8s-fabric
# (no pipefail: grep -q exiting early would SIGPIPE the producer and
# turn passing checks into flaky failures)
set -u

P=clab-k8s-fabric
K() { docker exec "$P-k3s1" kubectl "$@" 2>/dev/null; }
TOR() { docker exec "$P-tor" vtysh -c "$1" 2>/dev/null; }
PASS=0
FAIL=0

ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

for node in tor racksw k3s1 k3s2 client; do
    docker inspect "$P-$node" >/dev/null 2>&1 \
        && ok "$node container running" \
        || bad "$node container running"
done

# Both k3s nodes Ready
ready=$(K get nodes --no-headers | grep -cw Ready)
[ "$ready" -eq 2 ] && ok "both k3s nodes Ready" || bad "both k3s nodes Ready (saw $ready)"

# MetalLB running (controller + 2 speakers)
mlb=$(K -n metallb-system get pods --no-headers | grep -c Running)
[ "$mlb" -ge 3 ] && ok "MetalLB running ($mlb pods)" || bad "MetalLB running (saw $mlb)"

# ToR has both BGP sessions Established
est=$(TOR 'show bgp ipv4 unicast summary json' | grep -c '"state":"Established"')
[ "$est" -eq 2 ] && ok "ToR has 2 Established BGP sessions" || bad "ToR has 2 Established BGP sessions (saw $est)"

# The LoadBalancer service has an external IP from the pool
VIP=$(K get svc web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
case "$VIP" in
    198.51.100.*) ok "web-lb has VIP $VIP from the pool" ;;
    *) bad "web-lb has a VIP from the pool (saw '${VIP:-none}')"; VIP="" ;;
esac

# ToR installed the VIP /32 as ECMP across both nodes
if [ -n "$VIP" ]; then
    nh=$(TOR "show ip route $VIP/32" | grep -c 'via eth1')
    [ "$nh" -eq 2 ] && ok "ToR VIP route is ECMP (2 next-hops)" \
                    || bad "ToR VIP route is ECMP (saw $nh next-hops — maximum-paths set? both nodes advertising?)"

    # Data path: client reaches the service through the fabric
    if docker exec "$P-client" wget -qO- --timeout=5 "http://$VIP/" 2>/dev/null | grep -q 'Welcome to nginx'; then
        ok "client reaches the service VIP through the ToR"
    else
        bad "client reaches the service VIP through the ToR"
    fi
fi

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
