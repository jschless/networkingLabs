#!/usr/bin/env bash
# Reset transient NHRP state, then require all six directional relationships.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase2/seed-shortcuts.sh' \
        '' \
        'Bounded-clear ephemeral NHRP shortcut/cache state on all spokes, send' \
        'source-specific traffic, and require overlay plus direct-FIB correlation.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase2
for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase2 is not fully deployed" >&2
        exit 1
    }
done

# A retained transient entry can suppress a fresh resolution exchange. Reset
# only ephemeral operational state so every invocation starts from the same
# local-plus-NHS baseline. These commands do not enter configure mode, write
# /config/config.boot, or alter the reference.
for source in 1 2 3; do
    timeout 10 docker exec "$prefix-spoke$source" vtysh \
        -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null || {
        echo "ERROR: could not clear transient NHRP state on spoke$source" >&2
        exit 1
    }
done

ready=false
for _attempt in $(seq 1 30); do
    ping_pids=()
    for source in 1 2 3; do
        for destination in 1 2 3; do
            [[ "$source" == "$destination" ]] && continue
            timeout 5 docker exec "$prefix-spoke$source" \
                ping -I "192.168.${source}.1" -c 1 -W 1 \
                "192.168.${destination}.1" >/dev/null 2>&1 &
            ping_pids+=("$!")
        done
    done
    for ping_pid in "${ping_pids[@]}"; do
        wait "$ping_pid" || true
    done

    ready=true
    for source in 1 2 3; do
        nhrp=$(docker exec "$prefix-spoke$source" vtysh -c 'show ip nhrp' 2>/dev/null || true)
        for destination in 1 2 3; do
            [[ "$source" == "$destination" ]] && continue
            destination_last=$((10 + destination))
            grep -qE "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${destination_last}[[:space:]]+10\\.0\\.0\\.${destination_last}[[:space:]]+10\\.0\\.0\\.${destination_last}([[:space:]]|$)" \
                <<<"$nhrp" || ready=false
            fib=$(docker exec "$prefix-spoke$source" ip -4 route get \
                "192.168.${destination}.1" from "192.168.${source}.1" \
                2>/dev/null || true)
            grep -qE "^192\\.168\\.${destination}\\.1 from 192\\.168\\.${source}\\.1 (via 172\\.16\\.0\\.${destination_last} )?dev tun0([[:space:]]|$)" \
                <<<"$fib" || ready=false
        done
    done
    [[ "$ready" == true ]] && break
    sleep 1
done

[[ "$ready" == true ]] || {
    echo "ERROR: every directional overlay and direct-FIB relationship did not converge within the bounded wait" >&2
    exit 1
}

for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        timeout 5 docker exec "$prefix-spoke$source" \
            ping -I "192.168.${source}.1" -c 2 -W 1 \
            "192.168.${destination}.1" >/dev/null 2>&1 || {
            echo "ERROR: spoke${source}-to-spoke${destination} service traffic failed after seeding" >&2
            exit 1
        }
    done
done

echo "Transient NHRP state was reset; all six directional overlay mappings and direct FIBs are carrying service traffic without configuration changes."
