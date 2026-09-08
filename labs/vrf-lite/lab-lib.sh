#!/usr/bin/env bash
# Shared exact-state and transaction helpers for the VRF-Lite lab.

VL_PREFIX=clab-vrf-lite

vl_container() { printf '%s-%s\n' "$VL_PREFIX" "$1"; }

vl_running() {
    [[ "$(docker inspect --format '{{.State.Running}}' "$(vl_container "$1")" 2>/dev/null)" == true ]]
}

vl_eos() {
    timeout -k 5 15 docker exec "$(vl_container "$1")" \
        Cli -p 15 -c enable -c "$2" 2>/dev/null
}

vl_eos_config() {
    local node=$1
    timeout -k 5 20 docker exec -i "$(vl_container "$node")" Cli -p 15 >/dev/null
}

vl_node() {
    local node=$1
    shift
    timeout -k 5 10 docker exec "$(vl_container "$node")" "$@"
}

vl_require_tools() {
    local tool
    for tool in docker grep sed awk sort timeout mktemp; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "ERROR: required host command is unavailable: $tool" >&2
            return 1
        }
    done
}

vl_require_inventory() {
    local actual node image
    actual=$(docker ps --format '{{.Names}}' | sed -n 's/^clab-vrf-lite-//p' | LC_ALL=C sort)
    [[ "$actual" == $'ce-a1\nce-a2\nce-b1\nce-b2\npe1\npe2' ]] || return 1
    for node in pe1 pe2; do
        vl_running "$node" || return 1
        image=$(docker inspect --format '{{.Config.Image}}' "$(vl_container "$node")" 2>/dev/null)
        [[ "$image" == ceos:4.35.2F ]] || return 1
    done
    for node in ce-a1 ce-a2 ce-b1 ce-b2; do
        vl_running "$node" || return 1
        image=$(docker inspect --format '{{.Config.Image}}' "$(vl_container "$node")" 2>/dev/null)
        [[ "$image" == ops-lab:local ]] || return 1
    done
}

vl_config() {
    local node=$1 plane=$2 command='show running-config'
    [[ "$plane" == running ]] || command='show startup-config'
    vl_eos "$node" "$command"
}

# Normalize only lab-owned declarations. Any additional VRF, routed data-port,
# or static-route declaration therefore makes the comparison fail.
vl_task_tokens() {
    vl_config "$1" "$2" | awk '
        /^vrf instance / || /^ip routing vrf / || /^ip route / {
            line=$0; gsub(/[[:space:]]+/, " ", line); print "GLOBAL|" line
        }
        /^interface Ethernet[1-4]$/ { iface=$2; next }
        /^interface / { iface="" }
        iface != "" {
            line=$0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
            if (line ~ /^(no switchport|switchport|vrf |ip address |shutdown)$/ ||
                line ~ /^(vrf |ip address )/) print "IF|" iface "|" line
        }
    ' | LC_ALL=C sort
}

vl_expected_tokens() {
    local node=$1 mode=$2
    if [[ "$mode" == answer-free ]]; then
        return 0
    fi
    if [[ "$node" == pe1 ]]; then
        printf '%s\n' \
            'GLOBAL|vrf instance VRF-RED' \
            'GLOBAL|vrf instance VRF-BLUE' \
            'GLOBAL|ip routing vrf VRF-RED' \
            'GLOBAL|ip routing vrf VRF-BLUE' \
            'IF|Ethernet1|no switchport' \
            'IF|Ethernet1|vrf VRF-RED' \
            'IF|Ethernet1|ip address 10.10.12.2/30' \
            'IF|Ethernet2|no switchport' \
            'IF|Ethernet2|vrf VRF-RED' \
            'IF|Ethernet2|ip address 10.10.99.1/30' \
            'IF|Ethernet3|no switchport' \
            'IF|Ethernet3|vrf VRF-BLUE' \
            'IF|Ethernet3|ip address 10.20.12.2/30' \
            'IF|Ethernet4|no switchport' \
            'IF|Ethernet4|vrf VRF-BLUE' \
            'IF|Ethernet4|ip address 10.20.99.1/30' \
            'GLOBAL|ip route vrf VRF-RED 10.10.0.1/32 10.10.12.1' \
            'GLOBAL|ip route vrf VRF-RED 10.10.0.2/32 10.10.99.2' \
            'GLOBAL|ip route vrf VRF-BLUE 10.20.0.1/32 10.20.12.1' \
            'GLOBAL|ip route vrf VRF-BLUE 10.20.0.2/32 10.20.99.2'
        if [[ "$mode" == fault ]]; then
            printf '%s\n' 'GLOBAL|ip route vrf VRF-BLUE 10.10.0.1/32 10.10.12.1'
        else
            printf '%s\n' 'GLOBAL|ip route vrf VRF-BLUE 10.10.0.1/32 egress-vrf VRF-RED 10.10.12.1'
        fi
        printf '%s\n' 'GLOBAL|ip route vrf VRF-RED 10.20.0.1/32 egress-vrf VRF-BLUE 10.20.12.1'
    else
        printf '%s\n' \
            'GLOBAL|vrf instance VRF-RED' \
            'GLOBAL|vrf instance VRF-BLUE' \
            'GLOBAL|ip routing vrf VRF-RED' \
            'GLOBAL|ip routing vrf VRF-BLUE' \
            'IF|Ethernet1|no switchport' \
            'IF|Ethernet1|vrf VRF-RED' \
            'IF|Ethernet1|ip address 10.10.99.2/30' \
            'IF|Ethernet2|no switchport' \
            'IF|Ethernet2|vrf VRF-RED' \
            'IF|Ethernet2|ip address 10.10.34.1/30' \
            'IF|Ethernet3|no switchport' \
            'IF|Ethernet3|vrf VRF-BLUE' \
            'IF|Ethernet3|ip address 10.20.99.2/30' \
            'IF|Ethernet4|no switchport' \
            'IF|Ethernet4|vrf VRF-BLUE' \
            'IF|Ethernet4|ip address 10.20.34.1/30' \
            'GLOBAL|ip route vrf VRF-RED 10.10.0.1/32 10.10.99.1' \
            'GLOBAL|ip route vrf VRF-RED 10.10.0.2/32 10.10.34.2' \
            'GLOBAL|ip route vrf VRF-BLUE 10.20.0.1/32 10.20.99.1' \
            'GLOBAL|ip route vrf VRF-BLUE 10.20.0.2/32 10.20.34.2'
    fi | LC_ALL=C sort
}

vl_plane_exact() {
    local node=$1 plane=$2 mode=$3 actual expected config
    actual=$(vl_task_tokens "$node" "$plane") || return 1
    expected=$(vl_expected_tokens "$node" "$mode") || return 1
    [[ "$actual" == "$expected" ]] || return 1
    config=$(vl_config "$node" "$plane") || return 1
    ! grep -qE '^router (ospf|bgp|isis|rip)([[:space:]]|$)' <<<"$config"
}

vl_config_exact() {
    local mode=$1 node plane node_mode
    for node in pe1 pe2; do
        node_mode=$mode
        [[ "$node" == pe2 && "$mode" == fault ]] && node_mode=healthy
        for plane in running startup; do
            vl_plane_exact "$node" "$plane" "$node_mode" || return 1
        done
    done
}

vl_classify_config() {
    if vl_config_exact answer-free; then printf '%s\n' answer-free
    elif vl_config_exact healthy; then printf '%s\n' healthy
    elif vl_config_exact fault; then printf '%s\n' fault
    else return 1
    fi
}

vl_ce_scaffold_exact() {
    local node=$1 expected_link=$2 expected_loop=$3 expected_gateway=$4 addresses routes expected_network expected_source
    expected_source=${expected_link%/*}
    case "$node" in
        ce-a1) expected_network=10.10.12.0/30 ;;
        ce-a2) expected_network=10.10.34.0/30 ;;
        ce-b1) expected_network=10.20.12.0/30 ;;
        ce-b2) expected_network=10.20.34.0/30 ;;
        *) return 2 ;;
    esac
    addresses=$(vl_node "$node" sh -c \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort" 2>/dev/null) || return 1
    [[ "$addresses" == "eth1 $expected_link"$'\n'"lo $expected_loop" ]] \
        || [[ "$addresses" == "lo $expected_loop"$'\n'"eth1 $expected_link" ]] || return 1
    routes=$(vl_node "$node" sh -c \
        "ip -4 route show table main | grep -v ' dev eth0' | sed 's/[[:space:]]*\$//' | LC_ALL=C sort" \
        2>/dev/null) || return 1
    [[ "$routes" == \
        "$expected_network dev eth1 proto kernel scope link src $expected_source"$'\n'"default via $expected_gateway dev eth1" ]]
}

vl_ping() {
    local node=$1 source=$2 destination=$3
    vl_node "$node" ping -c 2 -W 1 -I "$source" "$destination" >/dev/null 2>&1
}

vl_same_tenant_healthy() {
    vl_ping ce-a1 10.10.0.1 10.10.0.2 \
        && vl_ping ce-a2 10.10.0.2 10.10.0.1 \
        && vl_ping ce-b1 10.20.0.1 10.20.0.2 \
        && vl_ping ce-b2 10.20.0.2 10.20.0.1
}

vl_shares_healthy() {
    vl_ping ce-a1 10.10.0.1 10.20.0.1 \
        && vl_ping ce-b1 10.20.0.1 10.10.0.1
}

vl_denials_healthy() {
    ! vl_ping ce-a1 10.10.0.1 10.20.0.2 \
        && ! vl_ping ce-a2 10.10.0.2 10.20.0.1 \
        && ! vl_ping ce-a2 10.10.0.2 10.20.0.2 \
        && ! vl_ping ce-b1 10.20.0.1 10.10.0.2 \
        && ! vl_ping ce-b2 10.20.0.2 10.10.0.1 \
        && ! vl_ping ce-b2 10.20.0.2 10.10.0.2
}

vl_interfaces_up() {
    local node=$1 interface detail
    for interface in Ethernet1 Ethernet2 Ethernet3 Ethernet4; do
        detail=$(vl_eos "$node" "show interfaces $interface") || return 1
        grep -qE "^[[:space:]]*${interface} is up, line protocol is up([[:space:]]|\\(|$)" \
            <<<"$detail" || return 1
    done
}

vl_route_active() {
    local node=$1 vrf=$2 prefix=$3 next_hop=$4 egress=${5:-} detail
    detail=$(vl_eos "$node" "show ip route vrf $vrf $prefix") || return 1
    grep -qE "${prefix//./\\.}" <<<"$detail" \
        && grep -qE "via[[:space:]]+${next_hop//./\\.}([,[:space:]]|$)" <<<"$detail" \
        && { [[ -z "$egress" ]] || grep -qE "\\(egress VRF ${egress}\\)" <<<"$detail"; }
}

vl_fib_exact() {
    vl_route_active pe1 VRF-RED 10.10.0.1/32 10.10.12.1 \
        && vl_route_active pe1 VRF-RED 10.10.0.2/32 10.10.99.2 \
        && vl_route_active pe1 VRF-BLUE 10.20.0.1/32 10.20.12.1 \
        && vl_route_active pe1 VRF-BLUE 10.20.0.2/32 10.20.99.2 \
        && vl_route_active pe2 VRF-RED 10.10.0.1/32 10.10.99.1 \
        && vl_route_active pe2 VRF-RED 10.10.0.2/32 10.10.34.2 \
        && vl_route_active pe2 VRF-BLUE 10.20.0.1/32 10.20.99.1 \
        && vl_route_active pe2 VRF-BLUE 10.20.0.2/32 10.20.34.2 \
        && vl_route_active pe1 VRF-BLUE 10.10.0.1/32 10.10.12.1 VRF-RED \
        && vl_route_active pe1 VRF-RED 10.20.0.1/32 10.20.12.1 VRF-BLUE
}

vl_default_clean() {
    local node=$1 routes
    routes=$(vl_eos "$node" 'show ip route') || return 1
    ! grep -qE '10\.(10|20)\.(0|12|34|99)\.' <<<"$routes"
}

vl_healthy_ready() {
    vl_config_exact healthy \
        && vl_interfaces_up pe1 && vl_interfaces_up pe2 \
        && vl_fib_exact && vl_default_clean pe1 && vl_default_clean pe2 \
        && vl_same_tenant_healthy && vl_shares_healthy && vl_denials_healthy
}

vl_fault_ready() {
    local detail
    vl_config_exact fault && vl_interfaces_up pe1 && vl_interfaces_up pe2 \
        && vl_same_tenant_healthy || return 1
    detail=$(vl_eos pe1 'show ip route vrf VRF-BLUE 10.10.0.1/32' 2>/dev/null || true)
    ! grep -qE 'via[[:space:]]+10\.10\.12\.1' <<<"$detail" \
        && ! vl_ping ce-a1 10.10.0.1 10.20.0.1 \
        && ! vl_ping ce-b1 10.20.0.1 10.10.0.1
}

vl_write_memory() {
    vl_eos "$1" 'copy running-config startup-config' >/dev/null
}

vl_make_backup() {
    local node=$1 backup test_fail=${VRF_LITE_BACKUP_TEST_FAIL_AFTER_MKDIR:-0}
    backup=$(timeout -k 5 25 docker exec -i \
        -e "VRF_LITE_BACKUP_TEST_FAIL_AFTER_MKDIR=$test_fail" \
        "$(vl_container "$node")" timeout -k 2 20 bash -s <<'EOF'
set -euo pipefail
umask 077
backup=
committed=false
cleanup() {
    status=$?
    trap - EXIT INT TERM
    if [[ "$committed" != true && -n "$backup" ]]; then
        rm -f "$backup/running-config" "$backup/startup-config" 2>/dev/null || true
        rmdir "$backup" 2>/dev/null || true
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
backup=$(mktemp -d /mnt/flash/vrf-lite.XXXXXX)
chmod 700 "$backup"
[[ ${VRF_LITE_BACKUP_TEST_FAIL_AFTER_MKDIR:-0} != 1 ]] || false
relative=${backup#/mnt/flash/}
timeout -k 2 12 Cli -p 15 \
    -c "copy running-config flash:$relative/running-config" >/dev/null
cp -p /mnt/flash/startup-config "$backup/startup-config"
chmod 600 "$backup/running-config" "$backup/startup-config"
committed=true
printf '%s\n' "$backup"
EOF
)
    [[ "$backup" =~ ^/mnt/flash/vrf-lite\.[[:alnum:]]{6}$ ]] || return 1
    printf '%s\n' "$backup"
}

vl_restore_backup() {
    local node=$1 backup=${2:-}
    [[ "$backup" =~ ^/mnt/flash/vrf-lite\.[[:alnum:]]{6}$ ]] || return 1
    timeout -k 5 25 docker exec -i "$(vl_container "$node")" \
        timeout -k 2 20 bash -s -- "$backup" <<'EOF'
set -euo pipefail
backup=$1
relative=${backup#/mnt/flash/}
timeout -k 2 12 Cli -p 15 -c enable \
    -c "configure replace flash:$relative/running-config" >/dev/null 2>&1
cp -p "$backup/startup-config" /mnt/flash/startup-config
EOF
}

vl_delete_backup() {
    local node=$1 backup=${2:-}
    [[ "$backup" =~ ^/mnt/flash/vrf-lite\.[[:alnum:]]{6}$ ]] || return 1
    timeout -k 5 15 docker exec -i "$(vl_container "$node")" \
        timeout -k 2 10 bash -s -- "$backup" <<'EOF'
set -euo pipefail
backup=$1
rm -f "$backup/running-config" "$backup/startup-config"
rmdir "$backup"
EOF
}
