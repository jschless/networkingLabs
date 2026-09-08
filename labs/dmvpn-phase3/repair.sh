#!/usr/bin/env bash
# Restore the live-only optimization fault and exact Phase 3 health.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3/repair.sh' \
        '' \
        'Restore only spoke1s live optimization leaf, preserve saved state,' \
        'reseed every current-image service-prefix /24 shortcut, and require check.sh.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3
lab_dir=$(cd "$(dirname "$0")" && pwd)
spoke="$prefix-spoke1"

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase3 is not fully deployed" >&2
        exit 1
    }
done

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
timeout 20 docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase3/restore-shortcut.sh' >/dev/null
"$lab_dir/seed-shortcuts.sh" >/dev/null
saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')

[[ "$saved_after" == "$saved_before" ]] || {
    echo "ERROR: repair changed the saved learner configuration" >&2
    exit 1
}

if ! "$lab_dir/check.sh"; then
    echo "ERROR: optimization repair did not restore the complete healthy build" >&2
    exit 1
fi

echo "Repair restored direct-path optimization, preserved saved state, and passed the full checker."
