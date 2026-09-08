#!/usr/bin/env bash
# Shared exact-state and transaction helpers for the BFD/OSPF lab.

BO_PREFIX=clab-bfd-ospf

bo_container() { printf '%s-%s\n' "$BO_PREFIX" "$1"; }

bo_running() {
    [[ "$(timeout -k 5 15 docker inspect --format '{{.State.Running}}' \
        "$(bo_container "$1")" 2>/dev/null)" == true ]]
}

bo_eos() {
    timeout -k 5 15 docker exec "$(bo_container "$1")" \
        Cli -p 15 -c enable -c "$2" 2>/dev/null
}

bo_eos_config() {
    local node=$1
    timeout -k 5 20 docker exec -i "$(bo_container "$node")" Cli -p 15 >/dev/null
}

bo_node() {
    local node=$1
    shift
    timeout -k 5 15 docker exec "$(bo_container "$node")" "$@"
}

bo_require_tools() {
    local tool
    for tool in docker grep sed awk sort timeout mktemp date seq sleep; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "ERROR: required host command is unavailable: $tool" >&2
            return 1
        }
    done
}

bo_require_inventory() {
    local actual node image
    actual=$(timeout -k 5 15 docker ps --format '{{.Names}}' \
        | sed -n 's/^clab-bfd-ospf-//p' | LC_ALL=C sort)
    [[ "$actual" == $'r1\nr2\nr3' ]] || return 1
    for node in r1 r2 r3; do
        bo_running "$node" || return 1
        image=$(timeout -k 5 15 docker inspect --format '{{.Config.Image}}' \
            "$(bo_container "$node")" 2>/dev/null)
        [[ "$image" == ceos:4.35.2F ]] || return 1
    done
}

bo_config() {
    local node=$1 plane=$2 command='show running-config'
    [[ "$plane" == running ]] || command='show startup-config'
    bo_eos "$node" "$command"
}

# Reduce the source-controlled base and all lab-owned declarations to an exact
# set. Relevant declarations on any unowned interface are emitted as drift.
bo_owned_tokens() {
    bo_config "$1" "$2" | awk '
        function clean(line) {
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            gsub(/[[:space:]]+/, " ", line)
            return line
        }
        /^[^[:space:]]/ {
            if ($0 !~ /^interface / && $0 !~ /^router /) {
                iface=""; router=""
            }
        }
        /^hostname / || /^ip routing$/ || /^ip route / || /^ipv6 route / || /^bfd / ||
        /^vrf instance / || /^ip routing vrf / {
            print "GLOBAL|" clean($0); next
        }
        /^router / {
            iface=""; router=clean($0); print "ROUTER|" router; next
        }
        /^interface / {
            router=""; iface=$2; next
        }
        router != "" && /^[[:space:]]+/ {
            line=clean($0)
            if (line != "" && line != "!") print "ROUTER|" router "|" line
            next
        }
        iface != "" && /^[[:space:]]+/ {
            line=clean($0)
            if (line ~ /^(no )?(switchport|shutdown|ip address|ip ospf|bfd)([[:space:]]|$)/) {
                if (iface ~ /^(Loopback0|Ethernet1|Ethernet2)$/)
                    print "IF|" iface "|" line
                else if (iface != "Management0")
                    print "OTHER-IF|" iface "|" line
            }
        }
    ' | LC_ALL=C sort
}

bo_expected_tokens() {
    local node=$1 mode=$2 router_id loop e1_address e2_address
    case "$node" in
        r1)
            router_id=10.0.0.1; loop=10.0.0.1/32
            e1_address=10.1.12.1/30; e2_address=10.1.13.1/30
            ;;
        r2)
            router_id=10.0.0.2; loop=10.0.0.2/32
            e1_address=10.1.12.2/30; e2_address=10.1.23.1/30
            ;;
        r3)
            router_id=10.0.0.3; loop=10.0.0.3/32
            e1_address=10.1.23.2/30; e2_address=10.1.13.2/30
            ;;
        *) return 2 ;;
    esac

    {
        printf '%s\n' \
            "GLOBAL|hostname $node" \
            'GLOBAL|ip routing' \
            "IF|Loopback0|ip address $loop" \
            'IF|Ethernet1|no switchport' \
            "IF|Ethernet1|ip address $e1_address" \
            'IF|Ethernet2|no switchport' \
            "IF|Ethernet2|ip address $e2_address"

        if [[ "$mode" != answer-free ]]; then
            printf '%s\n' \
                'IF|Loopback0|ip ospf area 0.0.0.0' \
                'IF|Ethernet1|ip ospf area 0.0.0.0' \
                'IF|Ethernet1|ip ospf network point-to-point' \
                'IF|Ethernet2|ip ospf area 0.0.0.0' \
                'IF|Ethernet2|ip ospf network point-to-point' \
                'IF|Ethernet2|bfd interval 300 min-rx 300 multiplier 3' \
                'ROUTER|router ospf 1' \
                'ROUTER|router ospf 1|bfd default' \
                'ROUTER|router ospf 1|max-lsa 12000' \
                "ROUTER|router ospf 1|router-id $router_id"
            if [[ "$node" == r2 && "$mode" == fault ]]; then
                printf '%s\n' 'IF|Ethernet1|bfd interval 3000 min-rx 3000 multiplier 3'
            else
                printf '%s\n' 'IF|Ethernet1|bfd interval 300 min-rx 300 multiplier 3'
            fi
        fi
    } | LC_ALL=C sort
}

bo_plane_exact() {
    local node=$1 plane=$2 mode=$3 actual expected
    actual=$(bo_owned_tokens "$node" "$plane") || return 1
    expected=$(bo_expected_tokens "$node" "$mode") || return 1
    [[ "$actual" == "$expected" ]]
}

bo_config_exact() {
    local mode=$1 node plane node_mode
    for node in r1 r2 r3; do
        node_mode=$mode
        [[ "$node" == r2 && "$mode" == fault ]] || node_mode=${mode/fault/healthy}
        for plane in running startup; do
            bo_plane_exact "$node" "$plane" "$node_mode" || return 1
        done
    done
}

bo_classify_config() {
    if bo_config_exact answer-free; then printf '%s\n' answer-free
    elif bo_config_exact healthy; then printf '%s\n' healthy
    elif bo_config_exact fault; then printf '%s\n' fault
    else return 1
    fi
}

bo_interfaces_up() {
    local node=$1 interface detail
    for interface in Loopback0 Ethernet1 Ethernet2; do
        detail=$(bo_eos "$node" "show interfaces $interface") || return 1
        grep -qE "^[[:space:]]*${interface} is up, line protocol is up([[:space:]]|\\(|$)" \
            <<<"$detail" || return 1
    done
}

bo_ospf_neighbor_tokens() {
    bo_eos "$1" 'show ip ospf neighbor' | awk '
        $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            peer=$1; address=""; iface=""; state=""
            for (i=2; i<=NF; i++) {
                value=$i; gsub(/,/, "", value)
                if (toupper(value) ~ /^FULL([\/-].*)?$/) state="Full"
                if (value ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) address=value
                if (value ~ /^Ethernet[0-9]+$/) iface=value
            }
            if (address != "" && iface != "" && state != "")
                print peer "|" address "|" iface "|" state
        }
    ' | LC_ALL=C sort
}

bo_expected_neighbors() {
    case "$1" in
        r1) printf '%s\n' '10.0.0.2|10.1.12.2|Ethernet1|Full' '10.0.0.3|10.1.13.2|Ethernet2|Full' ;;
        r2) printf '%s\n' '10.0.0.1|10.1.12.1|Ethernet1|Full' '10.0.0.3|10.1.23.2|Ethernet2|Full' ;;
        r3) printf '%s\n' '10.0.0.1|10.1.13.1|Ethernet2|Full' '10.0.0.2|10.1.23.1|Ethernet1|Full' ;;
        *) return 2 ;;
    esac | LC_ALL=C sort
}

bo_ospf_neighbors_exact() {
    local node=$1 actual expected
    actual=$(bo_ospf_neighbor_tokens "$node") || return 1
    expected=$(bo_expected_neighbors "$node") || return 1
    [[ "$actual" == "$expected" ]]
}

bo_bfd_peer_tokens() {
    bo_eos "$1" 'show bfd peers detail' | awk '
        /^[[:space:]]*Peer Addr / {
            peer=$3; gsub(/,/, "", peer); iface=""; state=""
            for (i=2; i<=NF; i++) {
                value=$i; gsub(/,/, "", value)
                if ($i == "Intf" && i < NF) {
                    iface=$(i+1); gsub(/,/, "", iface)
                }
                if ($i == "State" && i < NF) {
                    state=$(i+1); gsub(/,/, "", state)
                }
            }
            if (peer ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ &&
                iface ~ /^Ethernet[0-9]+$/ && state != "")
                print peer "|" iface "|" state
        }
    ' | LC_ALL=C sort
}

bo_expected_bfd_peers() {
    case "$1" in
        r1) printf '%s\n' '10.1.12.2|Ethernet1|Up' '10.1.13.2|Ethernet2|Up' ;;
        r2) printf '%s\n' '10.1.12.1|Ethernet1|Up' '10.1.23.2|Ethernet2|Up' ;;
        r3) printf '%s\n' '10.1.13.1|Ethernet2|Up' '10.1.23.1|Ethernet1|Up' ;;
        *) return 2 ;;
    esac | LC_ALL=C sort
}

bo_bfd_detail_block() {
    local node=$1 peer=$2
    bo_eos "$node" 'show bfd peers detail' | awk -v peer="$peer" '
        /^[[:space:]]*Peer Addr / {
            active=($0 ~ ("Peer Addr " peer "([,[:space:]]|$)"))
        }
        active { print }
    '
}

bo_bfd_detail_exact() {
    local node=$1 peer=$2 interface=$3 interval=$4 detect=$5 block
    block=$(bo_bfd_detail_block "$node" "$peer") || return 1
    [[ -n "$block" ]] || return 1
    grep -qE "^[[:space:]]*Peer Addr ${peer//./\\.},[[:space:]]+Intf ${interface}([,[:space:]]|$)" <<<"$block" \
        && grep -qE "TxInt:[[:space:]]*${interval}[[:space:]]*ms" <<<"$block" \
        && grep -qE "RxInt:[[:space:]]*${interval}[[:space:]]*ms" <<<"$block" \
        && grep -qE 'Multiplier:[[:space:]]*3([,[:space:]]|$)' <<<"$block" \
        && grep -qE "Detect Time:[[:space:]]*${detect}[[:space:]]*ms" <<<"$block" \
        && grep -qiE 'Registered protocols:[[:space:]]*ospf([,[:space:]]|$)' <<<"$block" \
        && grep -qiE 'State[[:space:]]+Up|State:[[:space:]]*Up' <<<"$block"
}

bo_bfd_exact() {
    local mode=$1 node actual expected interval detect
    for node in r1 r2 r3; do
        actual=$(bo_bfd_peer_tokens "$node") || return 1
        expected=$(bo_expected_bfd_peers "$node") || return 1
        [[ "$actual" == "$expected" ]] || return 1
    done
    while read -r node peer interface; do
        interval=300; detect=900
        if [[ "$mode" == fault ]] && { [[ "$node $peer" == 'r1 10.1.12.2' ]] || [[ "$node $peer" == 'r2 10.1.12.1' ]]; }; then
            interval=3000; detect=9000
        fi
        bo_bfd_detail_exact "$node" "$peer" "$interface" "$interval" "$detect" || return 1
    done <<'EOF'
r1 10.1.12.2 Ethernet1
r1 10.1.13.2 Ethernet2
r2 10.1.12.1 Ethernet1
r2 10.1.23.2 Ethernet2
r3 10.1.13.1 Ethernet2
r3 10.1.23.1 Ethernet1
EOF
}

bo_ospf_route_tokens() {
    bo_eos "$1" 'show ip route ospf' | awk '
        $1 == "O" && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ {
            prefix=$2; print "ROUTE|" prefix
        }
        prefix != "" && /via[[:space:]]+[0-9]+\./ {
            hop=""; iface=""
            for (i=1; i<=NF; i++) {
                value=$i; gsub(/,/, "", value)
                if ($i == "via" && i < NF) { hop=$(i+1); gsub(/,/, "", hop) }
                if (value ~ /^Ethernet[0-9]+$/) iface=value
            }
            if (hop != "" && iface != "") print "PATH|" prefix "|" hop "|" iface
        }
    ' | LC_ALL=C sort
}

bo_expected_routes() {
    case "$1" in
        r1) printf '%s\n' \
            'ROUTE|10.0.0.2/32' 'PATH|10.0.0.2/32|10.1.12.2|Ethernet1' \
            'ROUTE|10.0.0.3/32' 'PATH|10.0.0.3/32|10.1.13.2|Ethernet2' \
            'ROUTE|10.1.23.0/30' 'PATH|10.1.23.0/30|10.1.12.2|Ethernet1' \
            'PATH|10.1.23.0/30|10.1.13.2|Ethernet2' ;;
        r2) printf '%s\n' \
            'ROUTE|10.0.0.1/32' 'PATH|10.0.0.1/32|10.1.12.1|Ethernet1' \
            'ROUTE|10.0.0.3/32' 'PATH|10.0.0.3/32|10.1.23.2|Ethernet2' \
            'ROUTE|10.1.13.0/30' 'PATH|10.1.13.0/30|10.1.12.1|Ethernet1' \
            'PATH|10.1.13.0/30|10.1.23.2|Ethernet2' ;;
        r3) printf '%s\n' \
            'ROUTE|10.0.0.1/32' 'PATH|10.0.0.1/32|10.1.13.1|Ethernet2' \
            'ROUTE|10.0.0.2/32' 'PATH|10.0.0.2/32|10.1.23.1|Ethernet1' \
            'ROUTE|10.1.12.0/30' 'PATH|10.1.12.0/30|10.1.13.1|Ethernet2' \
            'PATH|10.1.12.0/30|10.1.23.1|Ethernet1' ;;
        *) return 2 ;;
    esac | LC_ALL=C sort
}

bo_routes_exact() {
    local node=$1 actual expected
    actual=$(bo_ospf_route_tokens "$node") || return 1
    expected=$(bo_expected_routes "$node") || return 1
    [[ "$actual" == "$expected" ]]
}

bo_ping() {
    local node=$1 source=$2 destination=$3 output
    output=$(bo_eos "$node" "ping $destination source $source repeat 2 timeout 1") || return 1
    grep -qE '^[[:space:]]*2 packets transmitted, 2 received, 0% packet loss([,[:space:]]|$)' <<<"$output"
}

bo_all_pings() {
    bo_ping r1 10.0.0.1 10.0.0.2 \
        && bo_ping r2 10.0.0.2 10.0.0.1 \
        && bo_ping r1 10.0.0.1 10.0.0.3 \
        && bo_ping r3 10.0.0.3 10.0.0.1 \
        && bo_ping r2 10.0.0.2 10.0.0.3 \
        && bo_ping r3 10.0.0.3 10.0.0.2
}

bo_control_plane_exact() {
    local node
    for node in r1 r2 r3; do
        bo_interfaces_up "$node" \
            && bo_ospf_neighbors_exact "$node" \
            && bo_routes_exact "$node" || return 1
    done
}

bo_healthy_ready() {
    bo_config_exact healthy && bo_control_plane_exact \
        && bo_bfd_exact healthy && bo_all_pings
}

bo_fault_ready() {
    bo_config_exact fault && bo_control_plane_exact \
        && bo_bfd_exact fault && bo_all_pings
}

bo_write_memory() {
    bo_eos "$1" 'copy running-config startup-config' >/dev/null
}

bo_make_backup() {
    local node=$1 backup test_fail=${BFD_OSPF_BACKUP_TEST_FAIL_AFTER_MKDIR:-0}
    backup=$(timeout -k 5 25 docker exec -i \
        -e "BFD_OSPF_BACKUP_TEST_FAIL_AFTER_MKDIR=$test_fail" \
        "$(bo_container "$node")" timeout -k 2 20 bash -s <<'EOF'
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
backup=$(mktemp -d /mnt/flash/bfd-ospf.XXXXXX)
chmod 700 "$backup"
[[ ${BFD_OSPF_BACKUP_TEST_FAIL_AFTER_MKDIR:-0} != 1 ]] || false
relative=${backup#/mnt/flash/}
timeout -k 2 12 Cli -p 15 \
    -c "copy running-config flash:$relative/running-config" >/dev/null
cp -p /mnt/flash/startup-config "$backup/startup-config"
chmod 600 "$backup/running-config" "$backup/startup-config"
committed=true
printf '%s\n' "$backup"
EOF
)
    [[ "$backup" =~ ^/mnt/flash/bfd-ospf\.[[:alnum:]]{6}$ ]] || return 1
    printf '%s\n' "$backup"
}

bo_restore_backup() {
    local node=$1 backup=${2:-}
    [[ "$backup" =~ ^/mnt/flash/bfd-ospf\.[[:alnum:]]{6}$ ]] || return 1
    timeout -k 5 25 docker exec -i "$(bo_container "$node")" \
        timeout -k 2 20 bash -s -- "$backup" <<'EOF'
set -euo pipefail
backup=$1
relative=${backup#/mnt/flash/}
timeout -k 2 12 Cli -p 15 -c enable \
    -c "configure replace flash:$relative/running-config" >/dev/null 2>&1
cp -p "$backup/startup-config" /mnt/flash/startup-config
EOF
}

bo_delete_backup() {
    local node=$1 backup=${2:-}
    [[ "$backup" =~ ^/mnt/flash/bfd-ospf\.[[:alnum:]]{6}$ ]] || return 1
    timeout -k 5 15 docker exec -i "$(bo_container "$node")" \
        timeout -k 2 10 bash -s -- "$backup" <<'EOF'
set -euo pipefail
backup=$1
rm -f "$backup/running-config" "$backup/startup-config"
rmdir "$backup"
EOF
}

bo_wait_state() {
    local state=$1 attempts=${2:-45}
    for _attempt in $(seq 1 "$attempts"); do
        case "$state" in
            answer-free) bo_config_exact answer-free && return 0 ;;
            healthy) bo_healthy_ready && return 0 ;;
            fault) bo_fault_ready && return 0 ;;
            *) return 2 ;;
        esac
        sleep 1
    done
    return 1
}
