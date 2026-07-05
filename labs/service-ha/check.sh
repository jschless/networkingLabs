#!/usr/bin/env bash
# Automated end-state assertions for the service-ha lab.
# Run via: ./scripts/lab.sh check service-ha
# (no pipefail: grep -q exiting early would SIGPIPE the producer and
# turn passing checks into flaky failures)
#
# The failover-survival check fails fw1 briefly and restores it — the lab
# is left as it started (fw1 MASTER).
set -u

P=clab-service-ha
PASS=0
FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
X() { docker exec "$P-$1" sh -c "$2" 2>/dev/null; }

for node in outsw insw fw1 fw2 client backend; do
    docker inspect "$P-$node" >/dev/null 2>&1 \
        && ok "$node container running" || bad "$node container running"
done

# keepalived: fw1 is MASTER (holds both VIPs), fw2 is BACKUP (holds neither)
if X fw1 'ip -4 addr show' | grep -q '10.10.0.1/24' && X fw1 'ip -4 addr show' | grep -q '10.10.20.1/24'; then
    ok "fw1 is MASTER (holds both VIPs)"
else
    bad "fw1 is MASTER (holds both VIPs)"
fi
if X fw2 'ip -4 addr show' | grep -q '10.10.0.1/24'; then
    bad "fw2 is BACKUP (should hold no VIP)"
else
    ok "fw2 is BACKUP (holds no VIP)"
fi

# stateful ruleset + the lab-critical sysctl
X fw1 'nft list ruleset' | grep -q 'ct state invalid drop' \
    && ok "fw1 nftables drops INVALID (stateful forward chain)" \
    || bad "fw1 nftables drops INVALID (stateful forward chain)"
[ "$(X fw1 'cat /proc/sys/net/netfilter/nf_conntrack_tcp_loose')" = "0" ] \
    && ok "fw1 tcp_loose=0 (orphaned mid-stream packets are INVALID)" \
    || bad "fw1 tcp_loose=0"

# conntrackd running on both
X fw1 'pgrep conntrackd >/dev/null' && ok "conntrackd running on fw1" || bad "conntrackd running on fw1"
X fw2 'pgrep conntrackd >/dev/null' && ok "conntrackd running on fw2" || bad "conntrackd running on fw2"

# client reaches the backend through the pair
if X client 'ping -c2 -W1 10.10.20.10' | grep -q ' 0% packet loss'; then
    ok "client reaches backend through the active firewall"
else
    bad "client reaches backend through the active firewall"
fi

# conntrackd state sync: a live flow on fw1 appears in fw2's external cache
X backend 'pgrep -x iperf3 >/dev/null || (iperf3 -s >/var/log/iperf.log 2>&1 &)'
docker exec -d "$P-client" sh -c 'iperf3 -c 10.10.20.10 -t 30 -i 1 --forceflush >/tmp/chk.txt 2>&1'
sleep 5
synced=$(X fw2 'conntrackd -e' | grep -c 5201)
[ "${synced:-0}" -ge 1 ] \
    && ok "fw1's active flow is replicated to fw2 (conntrackd external cache)" \
    || bad "fw1's active flow is replicated to fw2 (conntrackd external cache)"

# failover survival: kill fw1, the in-flight flow must keep passing
X fw1 'ip link set eth1 down; ip link set eth2 down'
sleep 10
# the final interval printed before fw1 comes back must be non-zero
lastrate=$(X client "grep -E '[0-9]\.00- *[0-9]' /tmp/chk.txt | tail -1")
if echo "$lastrate" | grep -qE '[0-9.]+ [GMK]bits/sec' && ! echo "$lastrate" | grep -q '0.00 bits/sec'; then
    ok "flow SURVIVES failover with conntrackd (post-failover throughput > 0)"
else
    bad "flow survives failover (last interval: ${lastrate:-none})"
fi
X fw1 'ip link set eth1 up; ip link set eth2 up'
X client 'pkill iperf3 2>/dev/null' || true
sleep 4   # let fw1 preempt back to MASTER before the script exits

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
