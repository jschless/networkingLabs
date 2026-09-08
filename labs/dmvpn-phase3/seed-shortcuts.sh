#!/usr/bin/env bash
# Reset transient state, then require all six Phase 3 direct service paths.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3/seed-shortcuts.sh' \
        '' \
        'Bounded-clear ephemeral NHRP state, send all six source-specific flows,' \
        'and require correlated overlay, service-host mapping, service-prefix /24' \
        'shortcut, and direct FIB state.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3
for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase3 is not fully deployed" >&2
        exit 1
    }
done

for source in 1 2 3; do
    timeout 10 docker exec "$prefix-spoke$source" vtysh \
        -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null || {
        echo "ERROR: could not clear transient NHRP state on spoke$source" >&2
        exit 1
    }
done

ready=false
for _attempt in $(seq 1 40); do
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
        shortcuts=$(docker exec "$prefix-spoke$source" vtysh \
            -c 'show ip nhrp shortcut' 2>/dev/null || true)
        for destination in 1 2 3; do
            [[ "$source" == "$destination" ]] && continue
            destination_last=$((10 + destination))
            grep -qE "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${destination_last}[[:space:]]+10\\.0\\.0\\.${destination_last}[[:space:]]+10\\.0\\.0\\.${destination_last}([[:space:]]|$)" \
                <<<"$nhrp" || ready=false
            grep -qE "^tun0[[:space:]]+dynamic[[:space:]]+192\\.168\\.${destination}\\.1[[:space:]]+10\\.0\\.0\\.${destination_last}[[:space:]]+10\\.0\\.0\\.${destination_last}([[:space:]]|$)" \
                <<<"$nhrp" || ready=false
            grep -qE "^[[:space:]]*dynamic[[:space:]]+192\\.168\\.${destination}\\.0/24[[:space:]]+172\\.16\\.0\\.${destination_last}[[:space:]]*$" \
                <<<"$shortcuts" || ready=false
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
    echo "ERROR: every directional Phase 3 host mapping and service-prefix shortcut did not converge within the bounded wait" >&2
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

echo "All six current-image service-host mappings and service-prefix /24 shortcuts are correlated and forwarding directly."
