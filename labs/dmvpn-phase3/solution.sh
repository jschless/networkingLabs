#!/usr/bin/env bash
# Replace, save, converge, and grade every learned spoke control-plane subtree.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3/solution.sh' \
        '' \
        'Reject out-of-scope spoke pollution, replace every learned NHRP and' \
        'OSPF subtree with the healthy answer, save, converge, and require check.sh.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3
lab_dir=$(cd "$(dirname "$0")" && pwd)

normalize_commands() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        LC_ALL=C sort
}

interface_commands() {
    grep -E '^set interfaces (dummy dum0|ethernet eth1|tunnel tun0)([[:space:]]|$)' | \
        normalize_commands
}

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase3 is not fully deployed" >&2
        exit 1
    }
done

# NHRP and OSPF are the learner-owned subtrees and are replaced below. Reject
# out-of-scope interface, BGP, and static-route changes instead of masking them.
for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    expected_interfaces=$(cat <<EOF | normalize_commands
set interfaces dummy dum0 address 192.168.${spoke_number}.1/24
set interfaces dummy dum0 description "Service LAN ${spoke_number}"
set interfaces ethernet eth1 address 10.0.0.${wan_last}/24
set interfaces ethernet eth1 description "WAN NBMA"
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces tunnel tun0 address 172.16.0.${wan_last}/32
set interfaces tunnel tun0 description "mGRE DMVPN Phase 3 spoke${spoke_number}"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
)
    live=$(docker exec "$prefix-$spoke" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null)
    saved=$(docker exec "$prefix-$spoke" \
        /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null)
    [[ "$(interface_commands <<<"$live")" == "$expected_interfaces" ]] || {
        echo "ERROR: $spoke has out-of-scope live interface pollution" >&2
        exit 1
    }
    [[ "$(interface_commands <<<"$saved")" == "$expected_interfaces" ]] || {
        echo "ERROR: $spoke has out-of-scope saved interface pollution" >&2
        exit 1
    }
    if grep -qE '^set protocols (bgp|static)([[:space:]]|$)' <<<"$live" \
        || grep -qE '^set protocols (bgp|static)([[:space:]]|$)' <<<"$saved"; then
        echo "ERROR: $spoke has out-of-scope BGP or static-route pollution" >&2
        exit 1
    fi
done

for spoke in spoke1 spoke2 spoke3; do
    timeout 30 docker exec "$prefix-$spoke" su - admin -c \
        '/bin/vbash /opt/dmvpn-phase3/apply-solution.sh' >/dev/null
done

converged=false
complete_samples=0
for _attempt in $(seq 1 60); do
    sample_complete=true
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    [[ "$(grep -Ec '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.1[123][[:space:]]' <<<"$hub_nhrp" || true)" == 3 ]] \
        || sample_complete=false
    [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 3 ]] \
        || sample_complete=false

    for spoke_number in 1 2 3; do
        spoke="spoke$spoke_number"
        spoke_neighbors=$(docker exec "$prefix-$spoke" vtysh \
            -c 'show ip ospf neighbor' 2>/dev/null || true)
        spoke_routes=$(docker exec "$prefix-$spoke" vtysh \
            -c 'show ip route ospf' 2>/dev/null || true)
        [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$spoke_neighbors" || true)" == 1 ]] \
            || sample_complete=false
        grep -qE '^10\.0\.0\.1[[:space:]].*Full/[^[:space:]]+[[:space:]].*172\.16\.0\.1([[:space:]]|$)' \
            <<<"$spoke_neighbors" || sample_complete=false
        grep -qE '^O>\*[[:space:]]+192\.168\.0\.0/16.*via 172\.16\.0\.1, tun0' \
            <<<"$spoke_routes" || sample_complete=false

        for other in 1 2 3; do
            [[ "$other" == "$spoke_number" ]] && continue
            other_last=$((10 + other))
            grep -qE "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${other_last}/32.*via 172\\.16\\.0\\.1, tun0" \
                <<<"$spoke_routes" || sample_complete=false
        done
    done

    if [[ "$sample_complete" == true ]]; then
        ((complete_samples += 1))
    else
        complete_samples=0
    fi
    if (( complete_samples >= 2 )); then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: complete NHRP, OSPF, summary, and remote-overlay routing was not ready for two consecutive samples within the bounded wait" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: basic convergence succeeded, but the full healthy-state checker failed" >&2
    exit 1
fi

echo "Healthy DMVPN Phase 3 state applied, saved, and verified by the full checker."
