#!/usr/bin/env bash
# Restore only the live spoke1 VTI key mismatch; saved files stay unchanged.
set -euo pipefail
prefix=clab-flexvpn-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)
for node in gw-a gw-b gw-c host-a host-b host-c internet; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2; exit 1;
    }
done
b_conf_before=$(docker exec "$prefix-gw-b" sha256sum /etc/ipsec.conf /etc/ipsec.secrets)
docker exec "$prefix-gw-b" bash /opt/flexvpn-basics/set-vti-key.sh healthy
recovered=false
for _attempt in $(seq 1 20); do
    if docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.3.10 >/dev/null 2>&1 \
        && [[ "$(docker exec "$prefix-gw-b" sha256sum /etc/ipsec.conf /etc/ipsec.secrets)" == "$b_conf_before" ]]; then
        recovered=true; break
    fi
    sleep 1
done
[[ "$recovered" == true ]] || { echo "ERROR: key repair did not restore both spoke1 paths" >&2; exit 1; }
"$lab_dir/check.sh" || {
    echo "ERROR: minimal key repair restored forwarding, but exact healthy grading failed; run solution.sh to replace polluted state" >&2
    exit 1
}
echo "Repair restored VTI key 1, unchanged IKE files, and the full healthy checker."
