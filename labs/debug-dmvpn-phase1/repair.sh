#!/usr/bin/env bash
# Correct only spoke1's live NHRP unicast map. Never save configuration.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/debug-dmvpn-phase1/repair.sh' '' \
        'Require exact incident or healthy state, repair only the live spoke1' \
        'unicast map, preserve saved startup, and grade exact health.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

saved_hashes() {
    local node
    for node in hub spoke1 spoke2 spoke3; do
        printf '%s %s\n' "$node" \
            "$(debug_dmvpn_node "$node" \
                "sha256sum /config/config.boot | cut -d ' ' -f 1")"
    done
}

set_map() {
    docker exec "$(debug_dmvpn_container spoke1)" su - admin -c \
        "/bin/vbash /opt/debug-dmvpn-phase1/set-map.sh $1" >/dev/null
}

incident_errors=
healthy_errors=
if incident_errors=$(debug_dmvpn_verify_state incident 2>&1); then
    current=incident
elif healthy_errors=$(debug_dmvpn_verify_state healthy 2>&1); then
    current=healthy
else
    echo 'ERROR: state is neither the exact incident nor the exact healthy contract.' >&2
    printf '%s\n%s\n' "$incident_errors" "$healthy_errors" >&2
    echo 'Remove unrelated pollution or redeploy before using the repair.' >&2
    exit 1
fi

saved_before=$(saved_hashes)
if [[ "$current" == incident ]]; then
    set_map 10.0.0.1
fi

converged=false
for _attempt in $(seq 1 50); do
    if debug_dmvpn_verify_state healthy >/dev/null 2>&1; then
        converged=true
        break
    fi
    sleep 1
done
[[ "$converged" == true ]] || {
    echo 'ERROR: the minimal live repair did not reach exact health in time' >&2
    exit 1
}
[[ "$(saved_hashes)" == "$saved_before" ]] || {
    echo 'ERROR: saved startup state changed during the live-only repair' >&2
    exit 1
}

"$LAB_DIR/check.sh"
echo 'Repair complete: the live map is healthy and the exact saved incident is unchanged.'
