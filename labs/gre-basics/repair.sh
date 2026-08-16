#!/usr/bin/env bash
# Apply only the Task 5 repair. Re-running is safe.
set -euo pipefail

prefix=clab-gre-basics
gateway="$prefix-gw-a"

[[ "$(docker inspect --format '{{.State.Running}}' "$gateway" 2>/dev/null)" == true ]] || {
    echo "ERROR: gre-basics is not deployed" >&2
    exit 1
}

docker exec -i "$gateway" Cli -p 15 >/dev/null <<'EOS'
enable
configure
no ip route 203.0.113.6/32 172.16.0.2
end
EOS

for _attempt in $(seq 1 50); do
    a_neighbor=$(docker exec "$gateway" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    b_neighbor=$(docker exec "$prefix-gw-b" Cli -p 15 -c enable \
        -c 'show ip ospf neighbor' 2>/dev/null || true)
    if grep -qE '10\.0\.0\.2.*[Ff][Uu][Ll][Ll]' <<<"$a_neighbor" \
        && grep -qE '10\.0\.0\.1.*[Ff][Uu][Ll][Ll]' <<<"$b_neighbor" \
        && docker exec "$prefix-host-a" ping -c 2 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 2 -W 1 192.168.1.10 >/dev/null 2>&1; then
        echo "Repair converged. Re-run the evidence sequence and full checker."
        exit 0
    fi
    sleep 1
done

echo "ERROR: repair did not reach its bounded recovery postcondition" >&2
exit 1
