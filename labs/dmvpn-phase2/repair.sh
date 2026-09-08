#!/usr/bin/env bash
# Remove the live wrong service-host map and restore exact shortcut health.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase2/repair.sh' \
        '' \
        'Remove only spoke1s live wrong service-host map, preserve saved state,' \
        'reseed shortcuts, and require the complete healthy checker.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase2
lab_dir=$(cd "$(dirname "$0")" && pwd)
spoke="$prefix-spoke1"

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase2 is not fully deployed" >&2
        exit 1
    }
done

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase2/restore-service-host-map.sh' >/dev/null
"$lab_dir/seed-shortcuts.sh" >/dev/null
saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')

[[ "$saved_after" == "$saved_before" ]] || {
    echo "ERROR: repair changed the saved reference configuration" >&2
    exit 1
}

if ! "$lab_dir/check.sh"; then
    echo "ERROR: service-host-map repair did not restore the complete healthy reference" >&2
    exit 1
fi

echo "Repair removed the live wrong service-host map, preserved saved state, and restored the full checker."
