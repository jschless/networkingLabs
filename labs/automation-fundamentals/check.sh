#!/usr/bin/env bash
# Automated end-state assertions for the automation-fundamentals lab.
# Run via: ./scripts/lab.sh check automation-fundamentals
set -uo pipefail

AUTOMATION=clab-automation-fundamentals-automation
PASS=0
FAIL=0

ok()   { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

eapi() {
    # eapi <mgmt-ip> <command> — runs one CLI command via eAPI, prints JSON
    docker exec "$AUTOMATION" curl -s --max-time 5 \
        -u admin:admin -H 'Content-Type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"runCmds\",\"params\":{\"version\":1,\"cmds\":[\"$2\"],\"format\":\"json\"},\"id\":\"check\"}" \
        "http://$1/command-api"
}

for node in r1 r2; do
    docker inspect "clab-automation-fundamentals-$node" >/dev/null 2>&1 \
        && ok "$node container running" \
        || bad "$node container running"
done

for entry in "r1 172.31.41.11" "r2 172.31.41.12"; do
    set -- $entry
    node=$1; ip=$2
    if eapi "$ip" "show version" | grep -q '"result"'; then
        ok "$node eAPI answers runCmds (Task 2)"
    else
        bad "$node eAPI answers runCmds (Task 2) — is 'management api http-commands' enabled with 'protocol http'?"
    fi
done

for entry in "r1 172.31.41.11 10.1.12.2" "r2 172.31.41.12 10.1.12.1"; do
    set -- $entry
    node=$1; ip=$2; peer=$3
    if eapi "$ip" "show ip bgp summary" | grep -q '"peerState": "Established"'; then
        ok "$node BGP peer $peer Established"
    else
        bad "$node BGP peer $peer Established"
    fi
done

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
