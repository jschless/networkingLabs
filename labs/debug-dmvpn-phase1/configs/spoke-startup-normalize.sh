#!/usr/bin/env bash
# Restore a source-intended static map after current-image boot migration.
set -euo pipefail

case ${1:-} in
    10.0.0.1|10.0.0.254) target=$1 ;;
    *) echo 'usage: spoke-startup-normalize.sh 10.0.0.1|10.0.0.254' >&2; exit 2 ;;
esac
(( $# == 1 )) || {
    echo 'usage: spoke-startup-normalize.sh 10.0.0.1|10.0.0.254' >&2
    exit 2
}

helper=/opt/debug-dmvpn-phase1/set-map.sh
marker=/tmp/debug-dmvpn-phase1-map.ready
expected="set protocols nhrp tunnel tun0 map tunnel-ip 172.16.0.1 nbma $target"
rm -f "$marker"

normalize_commands() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        sed '/^[[:space:]]*$/d' | LC_ALL=C sort
}

live_commands() {
    timeout 8 /bin/vbash -ic 'show configuration commands' 2>/dev/null
}

saved_commands() {
    timeout 8 /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null
}

base_ready() {
    local live saved
    live=$(live_commands) || return 1
    saved=$(saved_commands) || return 1
    [[ "$(grep -Ec "^set protocols nhrp tunnel tun0 network-id ['\"]?1['\"]?$" \
        <<<"$live" || true)" == 1 ]] || return 1
    [[ "$(grep -Ec "^set protocols nhrp tunnel tun0 registration-no-unique$" \
        <<<"$live" || true)" == 1 ]] || return 1
    [[ "$(grep -Ec "^set protocols nhrp tunnel tun0 network-id ['\"]?1['\"]?$" \
        <<<"$saved" || true)" == 1 ]] || return 1
    [[ "$(grep -Ec "^set protocols nhrp tunnel tun0 registration-no-unique$" \
        <<<"$saved" || true)" == 1 ]]
}

map_exact() {
    local commands=$1 map_lines
    map_lines=$(grep -E '^set protocols nhrp tunnel tun0 map ' <<<"$commands" | \
        normalize_commands || true)
    [[ "$map_lines" == "$expected" ]]
}

ready=false
for _attempt in $(seq 1 75); do
    if base_ready; then
        ready=true
        break
    fi
    sleep 1
done
[[ "$ready" == true ]] || {
    echo 'ERROR: VyOS configd/startup migration did not become ready in 75 seconds' >&2
    exit 1
}

for _attempt in $(seq 1 5); do
    if /bin/vbash "$helper" "$target" --save >/dev/null 2>&1; then
        live=$(live_commands || true)
        saved=$(saved_commands || true)
        if map_exact "$live" && map_exact "$saved"; then
            printf 'ready:%s\n' "$target" >"$marker"
            echo "Startup NHRP normalization verified live and saved state for $target."
            exit 0
        fi
    fi
    sleep 2
done

echo 'ERROR: startup NHRP normalization failed exact live/saved verification' >&2
exit 1
