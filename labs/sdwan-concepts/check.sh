#!/usr/bin/env bash
# Automated end-state assertions for the sdwan-concepts lab.
# Run via: ./scripts/lab.sh check sdwan-concepts
# (no pipefail: grep -q exiting early would SIGPIPE the producer and
# turn passing checks into flaky failures)
set -u

P=clab-sdwan-concepts
PASS=0
FAIL=0

ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

for node in branch1 branch2 mpls-core inet-core h1 h2; do
    docker inspect "$P-$node" >/dev/null 2>&1 \
        && ok "$node container running" \
        || bad "$node container running"
done

# Both overlay tunnels pass traffic
docker exec "$P-branch1" ping -c1 -W2 10.255.1.2 >/dev/null 2>&1 \
    && ok "tun-mpls overlay up (10.255.1.1 <-> 10.255.1.2)" \
    || bad "tun-mpls overlay up"
docker exec "$P-branch1" ping -c1 -W2 10.255.2.2 >/dev/null 2>&1 \
    && ok "tun-inet overlay up (10.255.2.1 <-> 10.255.2.2)" \
    || bad "tun-inet overlay up"

# End to end, both traffic classes
docker exec "$P-h1" ping -c2 -W2 10.2.0.10 >/dev/null 2>&1 \
    && ok "h1 -> h2 best-effort" \
    || bad "h1 -> h2 best-effort"
docker exec "$P-h1" ping -Q 184 -c2 -W2 10.2.0.10 >/dev/null 2>&1 \
    && ok "h1 -> h2 voice (DSCP EF)" \
    || bad "h1 -> h2 voice (DSCP EF)"

# Policy path selection: unmarked forwards via tun-inet, mark 1 via tun-mpls
if docker exec "$P-branch1" ip route get 10.2.0.10 from 10.1.0.10 iif eth1 2>/dev/null | grep -q tun-inet; then
    ok "default path is tun-inet"
else
    bad "default path is tun-inet"
fi
if docker exec "$P-branch1" ip route get 10.2.0.10 from 10.1.0.10 iif eth1 mark 1 2>/dev/null | grep -q tun-mpls; then
    ok "voice path (fwmark 1) is tun-mpls"
else
    bad "voice path (fwmark 1) is tun-mpls — failed over, or policy missing?"
fi

# Path monitors alive on both branches
for node in branch1 branch2; do
    docker exec "$P-$node" pgrep -f pathmon >/dev/null 2>&1 \
        && ok "$node pathmon running" \
        || bad "$node pathmon running"
done

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
