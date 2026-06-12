#!/usr/bin/env bash
# Automated end-state assertions for the load-balancer-basics lab.
# Run via: ./scripts/lab.sh check load-balancer-basics
# (no pipefail: grep -q exiting early would SIGPIPE the producer and
# turn passing checks into flaky failures)
set -u

CLIENT=clab-load-balancer-basics-client
PASS=0
FAIL=0

ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

for node in client edge edge2 lb web1 web2; do
    docker inspect "clab-load-balancer-basics-$node" >/dev/null 2>&1 \
        && ok "$node container running" \
        || bad "$node container running"
done

# Backends answer directly (reachability through edge)
for ip in 172.16.0.11 172.16.0.12; do
    if docker exec "$CLIENT" curl -s --max-time 3 "http://$ip/" | grep -q '^server: web'; then
        ok "backend $ip answers from client"
    else
        bad "backend $ip answers from client"
    fi
done

# HAProxy VIP balances across both backends (Tasks 2-4)
seen=$(for _ in $(seq 1 6); do
    docker exec "$CLIENT" curl -s --max-time 3 http://172.16.0.10/ | awk '/^server:/ {print $2}'
done | sort -u | tr '\n' ' ')
case "$seen" in
    *web1*web2*) ok "HAProxy VIP 172.16.0.10 alternates backends ($seen)" ;;
    *) bad "HAProxy VIP 172.16.0.10 alternates backends (saw: ${seen:-nothing} — is haproxy running with both backends up?)" ;;
esac

# HTTP mode + X-Forwarded-For (Task 4)
if docker exec "$CLIENT" curl -s --max-time 3 http://172.16.0.10/ | grep -q "x-forwarded-for: '203.0.113.2'"; then
    ok "X-Forwarded-For carries the real client IP (Task 4)"
else
    bad "X-Forwarded-For carries the real client IP (Task 4)"
fi

# NAT-mode VIP on edge (Task 5)
seen=$(for _ in $(seq 1 6); do
    docker exec "$CLIENT" curl -s --max-time 3 http://203.0.113.1:8080/ | awk '/^server:/ {print $2}'
done | sort -u | tr '\n' ' ')
case "$seen" in
    *web1*web2*) ok "NAT VIP 203.0.113.1:8080 alternates backends ($seen)" ;;
    *) bad "NAT VIP 203.0.113.1:8080 alternates backends (saw: ${seen:-nothing} — Task 5 nftables rule + symmetric return path?)" ;;
esac

# NAT mode preserves the client source IP
if docker exec "$CLIENT" curl -s --max-time 3 http://203.0.113.1:8080/ | grep -q '^client-ip-seen-by-backend: 203.0.113.2'; then
    ok "NAT VIP preserves client source IP (no proxy in path)"
else
    bad "NAT VIP preserves client source IP (no proxy in path)"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
