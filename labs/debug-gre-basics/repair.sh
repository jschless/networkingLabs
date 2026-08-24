#!/usr/bin/env bash
# Apply only the smallest live repair; never write the startup configuration.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

saved_hash() {
    debug_gre_node "$1" "sha256sum /mnt/flash/startup-config | cut -d ' ' -f 1"
}

incident_errors=
healthy_errors=
if incident_errors=$(debug_gre_verify_state incident 2>&1); then
    current=incident
elif healthy_errors=$(debug_gre_verify_state healthy 2>&1); then
    current=healthy
else
    echo 'ERROR: live/saved state is neither the exact incident nor exact healthy state.' >&2
    printf '%s\n' "$incident_errors" "$healthy_errors" >&2
    echo 'Remove unrelated pollution or redeploy before running the repair.' >&2
    exit 1
fi

before_a=$(saved_hash gw-a)
before_b=$(saved_hash gw-b)

if [[ "$current" == incident ]]; then
    docker exec -i "$(debug_gre_container gw-b)" Cli -p 15 >/dev/null <<'EOS'
enable
configure
interface Tunnel0
   tunnel destination 203.0.113.1
end
EOS
fi

converged=false
for _attempt in $(seq 1 45); do
    if debug_gre_verify_state healthy >/dev/null 2>&1 \
        && docker exec "$(debug_gre_container host-a)" \
            ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$(debug_gre_container host-b)" \
            ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1; then
        converged=true
        break
    fi
    sleep 1
done

[[ "$converged" == true ]] || {
    echo 'ERROR: the minimal live repair did not converge within the bounded wait' >&2
    exit 1
}
[[ "$(saved_hash gw-a)" == "$before_a" && "$(saved_hash gw-b)" == "$before_b" ]] || {
    echo 'ERROR: a saved startup configuration changed during the live repair' >&2
    exit 1
}

"$LAB_DIR/check.sh"
echo 'Repair complete: live forwarding is healthy and the saved incident is unchanged.'
