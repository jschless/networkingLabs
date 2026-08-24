#!/usr/bin/env bash
# Reset transient shortcut state, then require all six direct service paths.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/dmvpn-phase3-ipsec-capstone/seed-shortcuts.sh' '' \
        'Clear transient spoke shortcut/cache state, send all six source-specific' \
        'flows, and require correlated service mappings, /24 shortcuts, and FIBs.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
shortcut_data_rows() {
    awk '
        {
            row=$0
            sub(/^[[:space:]]+/, "", row)
            sub(/[[:space:]]+$/, "", row)
            gsub(/[[:space:]]+/, " ", row)
            if (row == "") next
            lower=tolower(row)
            if (lower ~ /^(type|prefix)([[:space:]]+(type|prefix|state|via|identity|nbma|interface))+$/) next
            if (lower ~ /^[-=]+([[:space:]]+[-=]+)*$/) next
            if (lower ~ /^%?[[:space:]]*no[[:space:]]+/) next
            print row
        }
    ' | LC_ALL=C sort
}

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo 'ERROR: the capstone is not fully deployed' >&2; exit 1;
    }
done
for source in 1 2 3; do
    timeout 10 docker exec "$prefix-spoke$source" vtysh \
        -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null
done

ready=false
for _attempt in $(seq 1 45); do
    pids=()
    for source in 1 2 3; do
        for destination in 1 2 3; do
            [[ "$source" == "$destination" ]] && continue
            timeout 5 docker exec "$prefix-spoke$source" \
                ping -I "192.168.${source}.1" -c 1 -W 1 \
                "192.168.${destination}.1" >/dev/null 2>&1 &
            pids+=("$!")
        done
    done
    for pid in "${pids[@]}"; do wait "$pid" || true; done
    ready=true
    for source in 1 2 3; do
        nhrp=$(docker exec "$prefix-spoke$source" vtysh -c 'show ip nhrp' 2>/dev/null || true)
        shortcuts=$(docker exec "$prefix-spoke$source" vtysh -c 'show ip nhrp shortcut' 2>/dev/null || true)
        expected_shortcuts=
        for destination in 1 2 3; do
            [[ "$source" == "$destination" ]] && continue
            remote_last=$((10 + destination))
            grep -qE "^tun0[[:space:]]+dynamic[[:space:]]+192\.168\.${destination}\.1[[:space:]]+10\.0\.0\.${remote_last}[[:space:]]+10\.0\.0\.${remote_last}([[:space:]]|$)" <<<"$nhrp" || ready=false
            grep -qE "^[[:space:]]*dynamic[[:space:]]+192\.168\.${destination}\.0/24[[:space:]]+172\.16\.0\.${remote_last}[[:space:]]+spoke${destination}\.dmvpn\.lab[[:space:]]*$" <<<"$shortcuts" || ready=false
            expected_shortcuts+="dynamic 192.168.${destination}.0/24 172.16.0.${remote_last} spoke${destination}.dmvpn.lab"$'\n'
            fib=$(docker exec "$prefix-spoke$source" ip -4 route get \
                "192.168.${destination}.1" from "192.168.${source}.1" 2>/dev/null || true)
            grep -qE "^192\.168\.${destination}\.1 from 192\.168\.${source}\.1 (via 172\.16\.0\.${remote_last} )?dev tun0([[:space:]]|$)" <<<"$fib" || ready=false
        done
        expected_shortcuts=$(sed '/^$/d' <<<"$expected_shortcuts" | LC_ALL=C sort)
        actual_shortcuts=$(shortcut_data_rows <<<"$shortcuts")
        [[ "$actual_shortcuts" == "$expected_shortcuts" ]] || ready=false
    done
    [[ "$ready" == true ]] && break
    sleep 1
done
[[ "$ready" == true ]] || {
    echo 'ERROR: all six encrypted Phase 3 shortcuts did not converge within the bound' >&2
    exit 1
}
echo 'All six service-host mappings, /24 shortcuts, and direct FIBs are ready.'
