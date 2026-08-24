#!/usr/bin/env bash
# Shared exact-state contract for the debug DMVPN lifecycle helpers.

DEBUG_DMVPN_PREFIX=clab-debug-dmvpn-phase1

debug_dmvpn_container() {
    printf '%s-%s\n' "$DEBUG_DMVPN_PREFIX" "$1"
}

debug_dmvpn_running() {
    [[ "$(docker inspect --format '{{.State.Running}}' \
        "$(debug_dmvpn_container "$1")" 2>/dev/null)" == true ]]
}

debug_dmvpn_node() {
    docker exec "$(debug_dmvpn_container "$1")" sh -c "$2" 2>/dev/null
}

debug_dmvpn_vyos() {
    docker exec "$(debug_dmvpn_container "$1")" su - admin -c \
        "/bin/vbash -ic '$2'" 2>/dev/null
}

debug_dmvpn_frr() {
    docker exec "$(debug_dmvpn_container "$1")" vtysh -c "$2" 2>/dev/null
}

debug_dmvpn_normalize() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        sed '/^[[:space:]]*$/d' | LC_ALL=C sort
}

debug_dmvpn_select() {
    grep -E "$1" | debug_dmvpn_normalize
}

debug_dmvpn_live_config() {
    debug_dmvpn_vyos "$1" 'show configuration commands'
}

debug_dmvpn_saved_config() {
    debug_dmvpn_node "$1" '/usr/bin/vyos-config-to-commands /config/config.boot'
}

debug_dmvpn_mgmt_metadata() {
    local node=$1 container_name bridge_label network_ref network_id raw
    local v4 v4_prefix v6 v6_prefix gateway subnet
    container_name=$(debug_dmvpn_container "$node")
    bridge_label=$(docker inspect --format \
        '{{index .Config.Labels "clab-mgmt-net-bridge"}}' "$container_name" \
        2>/dev/null) || return 1
    [[ "$bridge_label" =~ ^br-([[:xdigit:]]{12})$ ]] || return 1
    network_ref=${BASH_REMATCH[1]}
    network_id=$(docker network inspect --format '{{.Id}}' "$network_ref" \
        2>/dev/null) || return 1
    [[ "$network_id" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    raw=$(docker inspect --format \
        '{{range .NetworkSettings.Networks}}{{.NetworkID}}|{{.IPAddress}}|{{.IPPrefixLen}}|{{.Gateway}}|{{.GlobalIPv6Address}}|{{.GlobalIPv6PrefixLen}}{{println}}{{end}}' \
        "$container_name" 2>/dev/null | awk -F'|' -v wanted="$network_id" '
            $1 == wanted { matches++; print $2, $3, $4, $5, $6 }
            END { if (matches != 1) exit 1 }
        ') || return 1
    read -r v4 v4_prefix gateway v6 v6_prefix <<<"$raw"
    [[ "$v4" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    [[ "$v4_prefix" =~ ^[0-9]+$ ]] || return 1
    (( 10#$v4_prefix <= 32 )) || return 1
    [[ "$gateway" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    [[ "$v6" =~ ^[[:xdigit:]:]+$ ]] || return 1
    [[ "$v6_prefix" =~ ^[0-9]+$ ]] || return 1
    (( 10#$v6_prefix <= 128 )) || return 1
    subnet=$(python3 -c \
        'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' \
        "$v4/$v4_prefix") || return 1
    printf '%s/%s %s/%s %s %s\n' \
        "$v4" "$v4_prefix" "$v6" "$v6_prefix" "$gateway" "$subnet"
}

debug_dmvpn_expected_mgmt_interfaces() {
    local node=$1 v4 v6 _gateway _subnet
    read -r v4 v6 _gateway _subnet <<<"$(debug_dmvpn_mgmt_metadata "$node")" \
        || return 1
    printf 'set interfaces ethernet eth0 address %s\n' "$v4" "$v6" | \
        debug_dmvpn_normalize
}

debug_dmvpn_actual_mgmt_addresses() {
    debug_dmvpn_node "$1" \
        "ip -4 -o address show dev eth0 scope global | awk '{print \$2, \$4}'; ip -6 -o address show dev eth0 scope global | awk '{print \$2, \$4}'" \
        | LC_ALL=C sort
}

debug_dmvpn_expected_mgmt_addresses() {
    local node=$1 v4 v6 _gateway _subnet
    read -r v4 v6 _gateway _subnet <<<"$(debug_dmvpn_mgmt_metadata "$node")" \
        || return 1
    printf 'eth0 %s\neth0 %s\n' "$v4" "$v6" | LC_ALL=C sort
}

debug_dmvpn_actual_mgmt_routes() {
    debug_dmvpn_node "$1" \
        "ip -4 route show table main | grep ' dev eth0' | sed -E 's/[[:space:]]+\$//' | sort"
}

debug_dmvpn_expected_mgmt_routes() {
    local node=$1 v4 _v6 gateway subnet address
    read -r v4 _v6 gateway subnet <<<"$(debug_dmvpn_mgmt_metadata "$node")" \
        || return 1
    address=${v4%/*}
    printf '%s\n' \
        "default via $gateway dev eth0" \
        "$subnet dev eth0 proto kernel scope link src $address" | LC_ALL=C sort
}

debug_dmvpn_interface_v4() {
    debug_dmvpn_node "$1" "ip -4 -o address show dev $2" | \
        awk '{print $4}' | LC_ALL=C sort
}

debug_dmvpn_startup_marker_expected() {
    case "$1" in
        spoke1) printf '%s\n' 'ready:10.0.0.254' ;;
        spoke2|spoke3) printf '%s\n' 'ready:10.0.0.1' ;;
        *) return 2 ;;
    esac
}

debug_dmvpn_startup_normalized() {
    [[ "$(debug_dmvpn_node "$1" \
        'cat /tmp/debug-dmvpn-phase1-map.ready')" == \
        "$(debug_dmvpn_startup_marker_expected "$1")" ]]
}

debug_dmvpn_expected_interfaces() {
    local node=$1 management number
    management=$(debug_dmvpn_expected_mgmt_interfaces "$node") || return 1
    case "$node" in
        hub)
            cat <<EOF | debug_dmvpn_normalize
$management
set interfaces ethernet eth1 address 10.0.0.1/24
set interfaces ethernet eth1 description WAN NBMA
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces loopback lo
set interfaces tunnel tun0 address 172.16.0.1/32
set interfaces tunnel tun0 description mGRE DMVPN tunnel - hub
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
            ;;
        spoke1|spoke2|spoke3)
            number=${node#spoke}
            cat <<EOF | debug_dmvpn_normalize
$management
set interfaces dummy dum0 address 192.168.${number}.1/24
set interfaces dummy dum0 description Service LAN ${number}
set interfaces ethernet eth1 address 10.0.0.$((10 + number))/24
set interfaces ethernet eth1 description WAN NBMA
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces loopback lo
set interfaces tunnel tun0 address 172.16.0.$((10 + number))/32
set interfaces tunnel tun0 description mGRE DMVPN tunnel - spoke${number}
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
            ;;
        *) return 2 ;;
    esac
}

debug_dmvpn_expected_protocols() {
    local node=$1 mode=$2 number map_target
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2
    case "$node" in
        hub)
            cat <<'EOF' | debug_dmvpn_normalize
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 multicast dynamic
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 registration-no-unique
set protocols ospf area 0 network 172.16.0.1/32
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.1
EOF
            ;;
        spoke1|spoke2|spoke3)
            number=${node#spoke}
            map_target=10.0.0.1
            [[ "$node:$mode" == spoke1:incident ]] && map_target=10.0.0.254
            cat <<EOF | debug_dmvpn_normalize
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 map tunnel-ip 172.16.0.1 nbma $map_target
set protocols nhrp tunnel tun0 multicast 10.0.0.1
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 nhs tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols nhrp tunnel tun0 registration-no-unique
set protocols ospf area 0 network 172.16.0.$((10 + number))/32
set protocols ospf area 0 network 192.168.${number}.0/24
set protocols ospf interface dum0 passive
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.$((10 + number))
EOF
            ;;
        *) return 2 ;;
    esac
}

debug_dmvpn_config_exact() {
    local node=$1 mode=$2 plane=${3:-live} config
    if [[ "$plane" == live ]]; then
        config=$(debug_dmvpn_live_config "$node") || return 1
    elif [[ "$plane" == saved ]]; then
        config=$(debug_dmvpn_saved_config "$node") || return 1
    else
        return 2
    fi
    [[ "$(debug_dmvpn_select '^set interfaces ' <<<"$config")" == \
        "$(debug_dmvpn_expected_interfaces "$node")" ]] || return 1
    [[ "$(debug_dmvpn_select '^set protocols ' <<<"$config")" == \
        "$(debug_dmvpn_expected_protocols "$node" "$mode")" ]]
}

debug_dmvpn_mgmt_exact() {
    [[ "$(debug_dmvpn_actual_mgmt_addresses "$1")" == \
        "$(debug_dmvpn_expected_mgmt_addresses "$1")" ]] \
        && [[ "$(debug_dmvpn_actual_mgmt_routes "$1")" == \
            "$(debug_dmvpn_expected_mgmt_routes "$1")" ]]
}

debug_dmvpn_route_pollution() {
    local node=$1 wan overlay number line other last
    case "$node" in
        hub) wan=10.0.0.1; overlay=172.16.0.1 ;;
        spoke1|spoke2|spoke3)
            number=${node#spoke}
            wan=10.0.0.$((10 + number))
            overlay=172.16.0.$((10 + number))
            ;;
        *) return 2 ;;
    esac
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == *' dev eth0'* ]] && continue
        if [[ "$line" == "10.0.0.0/24 dev eth1 proto kernel scope link src $wan" ]] \
            || [[ "$line" == "$overlay dev tun0 proto kernel scope link src $overlay" ]]; then
            continue
        fi
        if [[ -n "${number:-}" && "$line" == \
            "192.168.${number}.0/24 dev dum0 proto kernel scope link src 192.168.${number}.1" ]]; then
            continue
        fi
        if [[ "$node" == hub ]]; then
            if [[ "$line" =~ ^172\.16\.0\.(11|12|13)[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+nhrp[[:space:]]+metric[[:space:]]+20$ ]]; then
                continue
            fi
            for other in 1 2 3; do
                last=$((10 + other))
                if [[ "$line" =~ ^172\.16\.0\.${last}[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+via[[:space:]]+172\.16\.0\.${last}[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+ospf[[:space:]]+metric[[:space:]]+20[[:space:]]+onlink$ ]] \
                    || [[ "$line" =~ ^192\.168\.${other}\.0/24[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+via[[:space:]]+172\.16\.0\.${last}[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+ospf[[:space:]]+metric[[:space:]]+20[[:space:]]+onlink$ ]]; then
                    continue 2
                fi
            done
        else
            if [[ "$line" =~ ^172\.16\.0\.1[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+nhrp[[:space:]]+metric[[:space:]]+20$ ]]; then
                continue
            fi
            for other in 1 2 3; do
                [[ "$other" == "$number" ]] && continue
                last=$((10 + other))
                if [[ "$line" =~ ^172\.16\.0\.${last}[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+via[[:space:]]+172\.16\.0\.1[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+ospf[[:space:]]+metric[[:space:]]+20[[:space:]]+onlink$ ]] \
                    || [[ "$line" =~ ^192\.168\.${other}\.0/24[[:space:]]+nhid[[:space:]]+[0-9]+[[:space:]]+via[[:space:]]+172\.16\.0\.1[[:space:]]+dev[[:space:]]+tun0[[:space:]]+proto[[:space:]]+ospf[[:space:]]+metric[[:space:]]+20[[:space:]]+onlink$ ]]; then
                    continue 2
                fi
            done
        fi
        printf '%s\n' "$line"
    done < <(debug_dmvpn_node "$node" \
        "ip -4 route show table main | sed -E 's/[[:space:]]+\$//' | sort")
}

debug_dmvpn_ping() {
    timeout 6 docker exec "$(debug_dmvpn_container "$1")" ping -I "$2" \
        -c 2 -W 1 "$3" >/dev/null 2>&1
}

debug_dmvpn_nhrp_exact() {
    local node=$1 mode=${2:-healthy} output number last other target=10.0.0.1
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2
    output=$(debug_dmvpn_frr "$node" 'show ip nhrp') || return 1
    if [[ "$node" == hub ]]; then
        [[ "$(grep -Ec '^tun0[[:space:]]' <<<"$output" || true)" == 4 ]] || return 1
        grep -qE '^tun0[[:space:]]+local[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)' \
            <<<"$output" || return 1
        for number in 1 2 3; do
            last=$((10 + number))
            grep -qE "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+T([[:space:]]|$)" \
                <<<"$output" || return 1
        done
    else
        number=${node#spoke}
        last=$((10 + number))
        [[ "$node:$mode" == spoke1:incident ]] && target=10.0.0.254
        [[ "$(grep -Ec '^tun0[[:space:]]' <<<"$output" || true)" == 2 ]] || return 1
        grep -qE "^tun0[[:space:]]+local[[:space:]]+172\\.16\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+-([[:space:]]|$)" \
            <<<"$output" || return 1
        grep -qE "^tun0[[:space:]]+static[[:space:]]+172\\.16\\.0\\.1[[:space:]]+${target//./\\.}[[:space:]]+-([[:space:]]|$)" \
            <<<"$output" || return 1
        for other in 1 2 3; do
            [[ "$other" == "$number" ]] && continue
            ! grep -qE "172\\.16\\.0\\.$((10 + other))" <<<"$output" || return 1
        done
    fi
}

debug_dmvpn_ospf_exact() {
    local node=$1 mode=${2:-healthy} output number last state
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2
    output=$(debug_dmvpn_frr "$node" 'show ip ospf neighbor') || return 1
    if [[ "$node" == hub ]]; then
        [[ "$(grep -Ec '^[0-9]+\.' <<<"$output" || true)" == 3 ]] || return 1
        for number in 1 2 3; do
            last=$((10 + number))
            state=Full
            [[ "$mode:$number" == incident:1 ]] && state=ExStart
            grep -qE "^10\\.0\\.0\\.${last}[[:space:]].*${state}/DROther[[:space:]].*172\\.16\\.0\\.${last}([[:space:]]|$)" \
                <<<"$output" || return 1
        done
    else
        state=Full
        [[ "$node:$mode" == spoke1:incident ]] && state=ExStart
        [[ "$(grep -Ec '^[0-9]+\.' <<<"$output" || true)" == 1 ]] || return 1
        grep -qE "^10\\.0\\.0\\.1[[:space:]].*${state}/DROther[[:space:]].*172\\.16\\.0\\.1([[:space:]]|$)" \
            <<<"$output"
    fi
}

debug_dmvpn_routes_exact() {
    local node=$1 mode=${2:-healthy} routes number other last expected_count
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2
    routes=$(debug_dmvpn_frr "$node" 'show ip route ospf') || return 1
    if [[ "$node" == hub ]]; then
        expected_count=3
        [[ "$mode" == incident ]] && expected_count=2
        [[ "$(grep -Ec '^O[^[:space:]]*[[:space:]]+192\.168\.[123]\.0/24' \
            <<<"$routes" || true)" == "$expected_count" ]] || return 1
        [[ "$(grep -Ec '^O[^[:space:]]*[[:space:]]+172\.16\.0\.(11|12|13)/32' \
            <<<"$routes" || true)" == "$expected_count" ]] || return 1
        for number in 1 2 3; do
            last=$((10 + number))
            if [[ "$mode:$number" == incident:1 ]]; then
                ! grep -qE '^O[^[:space:]]*[[:space:]]+(172\.16\.0\.11/32|192\.168\.1\.0/24)' \
                    <<<"$routes" || return 1
                continue
            fi
            grep -qE "^O[^[:space:]]*[[:space:]]+192\\.168\\.${number}\\.0/24.*via 172\\.16\\.0\\.${last}, tun0" \
                <<<"$routes" || return 1
            grep -qE "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${last}/32.*via 172\\.16\\.0\\.${last}, tun0" \
                <<<"$routes" || return 1
        done
    else
        number=${node#spoke}
        if [[ "$node:$mode" == spoke1:incident ]]; then
            ! grep -qE '^O[^[:space:]]*[[:space:]]+(172\.16\.0\.(12|13)/32|192\.168\.(2|3)\.0/24)' \
                <<<"$routes"
            return
        fi
        expected_count=2
        [[ "$mode" == incident ]] && expected_count=1
        [[ "$(grep -Ec '^O>\*[[:space:]]+192\.168\.[123]\.0/24' \
            <<<"$routes" || true)" == "$expected_count" ]] || return 1
        [[ "$(grep -Ec '^O>\*[[:space:]]+172\.16\.0\.(11|12|13)/32' \
            <<<"$routes" || true)" == "$expected_count" ]] || return 1
        for other in 1 2 3; do
            [[ "$other" == "$number" ]] && continue
            if [[ "$mode:$other" == incident:1 ]]; then
                ! grep -qE '^O[^[:space:]]*[[:space:]]+(172\.16\.0\.11/32|192\.168\.1\.0/24)' \
                    <<<"$routes" || return 1
                continue
            fi
            last=$((10 + other))
            grep -qE "^O[^[:space:]]*[[:space:]]+192\\.168\\.${other}\\.0/24.*via 172\\.16\\.0\\.1, tun0" \
                <<<"$routes" || return 1
            grep -qE "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${last}/32.*via 172\\.16\\.0\\.1, tun0" \
                <<<"$routes" || return 1
        done
    fi
}

debug_dmvpn_verify_state() {
    local mode=$1 errors=0 node image actual_nodes bridge_links bridge_ports
    local last
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2

    for node in br-wan hub spoke1 spoke2 spoke3; do
        if ! debug_dmvpn_running "$node"; then
            echo "ERROR: $node is not running" >&2
            errors=$((errors + 1))
        fi
    done
    (( errors == 0 )) || return 1

    actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
        's/^clab-debug-dmvpn-phase1-//p' | LC_ALL=C sort)
    [[ "$actual_nodes" == $'br-wan\nhub\nspoke1\nspoke2\nspoke3' ]] || {
        echo 'ERROR: target node inventory is not exact' >&2
        errors=$((errors + 1))
    }
    for node in hub spoke1 spoke2 spoke3; do
        image=$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_dmvpn_container "$node")" 2>/dev/null || true)
        [[ "$image" == vyos:local ]] || {
            echo "ERROR: $node is not native vyos:local" >&2
            errors=$((errors + 1))
        }
    done
    image=$(docker inspect --format '{{.Config.Image}}' \
        "$(debug_dmvpn_container br-wan)" 2>/dev/null || true)
    [[ "$image" == ops-lab:local ]] || {
        echo 'ERROR: br-wan is not incidental ops-lab:local' >&2
        errors=$((errors + 1))
    }

    for node in br-wan hub spoke1 spoke2 spoke3; do
        if ! debug_dmvpn_mgmt_exact "$node"; then
            echo "ERROR: $node management address/route inventory is polluted" >&2
            errors=$((errors + 1))
        fi
    done
    bridge_links=$(debug_dmvpn_node br-wan 'bridge link show master br0')
    bridge_ports=$(awk '{ port=$2; sub(/:.*/, "", port); sub(/@.*/, "", port); print port }' \
        <<<"$bridge_links" | LC_ALL=C sort)
    [[ "$bridge_ports" == $'eth1\neth2\neth3\neth4' \
        && "$(grep -Ec 'master br0 state forwarding' <<<"$bridge_links" || true)" == 4 ]] || {
        echo 'ERROR: WAN bridge membership/forwarding is not exact' >&2
        errors=$((errors + 1))
    }
    [[ -z "$(debug_dmvpn_node br-wan \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print}'")" \
        && -z "$(debug_dmvpn_node br-wan \
            "ip -4 route show table main | grep -v ' dev eth0'")" ]] || {
        echo 'ERROR: br-wan has data-plane address/route pollution' >&2
        errors=$((errors + 1))
    }

    for node in hub spoke1 spoke2 spoke3; do
        if ! debug_dmvpn_config_exact "$node" "$mode" live; then
            echo "ERROR: $node live interface/protocol configuration is not exact $mode state" >&2
            errors=$((errors + 1))
        fi
        if ! debug_dmvpn_config_exact "$node" incident saved; then
            echo "ERROR: $node saved configuration is not the exact intentional incident" >&2
            errors=$((errors + 1))
        fi
        if [[ -n "$(debug_dmvpn_route_pollution "$node")" ]]; then
            echo "ERROR: $node kernel route inventory is polluted" >&2
            errors=$((errors + 1))
        fi
        if ! debug_dmvpn_nhrp_exact "$node" "$mode"; then
            echo "ERROR: $node NHRP cardinality/correlation is not exact" >&2
            errors=$((errors + 1))
        fi
        if ! debug_dmvpn_ospf_exact "$node" "$mode"; then
            echo "ERROR: $node OSPF neighbor state is not exact" >&2
            errors=$((errors + 1))
        fi
        if ! debug_dmvpn_routes_exact "$node" "$mode"; then
            echo "ERROR: $node OSPF route ownership is not exact" >&2
            errors=$((errors + 1))
        fi
    done

    [[ "$(debug_dmvpn_interface_v4 hub eth1)" == '10.0.0.1/24' \
        && "$(debug_dmvpn_interface_v4 hub tun0)" == '172.16.0.1/32' ]] || {
        echo 'ERROR: hub data-plane address inventory is not exact' >&2
        errors=$((errors + 1))
    }
    for node in 1 2 3; do
        last=$((10 + node))
        [[ "$(debug_dmvpn_interface_v4 "spoke$node" eth1)" == "10.0.0.${last}/24" \
            && "$(debug_dmvpn_interface_v4 "spoke$node" tun0)" == "172.16.0.${last}/32" \
            && "$(debug_dmvpn_interface_v4 "spoke$node" dum0)" == "192.168.${node}.1/24" ]] || {
            echo "ERROR: spoke$node data-plane address inventory is not exact" >&2
            errors=$((errors + 1))
        }
    done

    for node in hub spoke1 spoke2 spoke3; do
        grep -qE 'gre remote any local any dev eth1' \
            <<<"$(debug_dmvpn_node "$node" 'ip -d link show dev tun0')" || {
            echo "ERROR: $node tun0 is not honest mGRE" >&2
            errors=$((errors + 1))
        }
    done
    for node in spoke1 spoke2 spoke3; do
        if ! debug_dmvpn_startup_normalized "$node"; then
            echo "ERROR: $node startup NHRP normalization marker is not exact" >&2
            errors=$((errors + 1))
        fi
    done

    for node in 1 2 3; do
        last=$((10 + node))
        debug_dmvpn_ping "spoke$node" "10.0.0.$last" 10.0.0.1 || {
            echo "ERROR: spoke$node underlay cannot reach hub" >&2
            errors=$((errors + 1))
        }
    done
    if [[ "$mode" == healthy ]]; then
        for node in 1 2 3; do
            last=$((10 + node))
            debug_dmvpn_ping "spoke$node" "172.16.0.$last" 172.16.0.1 || {
                echo "ERROR: spoke$node overlay cannot reach hub" >&2
                errors=$((errors + 1))
            }
        done
        for node in 1 2 3; do
            for last in 1 2 3; do
                [[ "$node" == "$last" ]] && continue
                debug_dmvpn_ping "spoke$node" "192.168.${node}.1" \
                    "192.168.${last}.1" || {
                    echo "ERROR: spoke$node cannot reach spoke$last service" >&2
                    errors=$((errors + 1))
                }
            done
        done
    else
        ! debug_dmvpn_ping spoke1 172.16.0.11 172.16.0.1 || {
            echo 'ERROR: spoke1 overlay unexpectedly succeeds in the incident' >&2
            errors=$((errors + 1))
        }
        ! debug_dmvpn_ping spoke1 192.168.1.1 192.168.2.1 || {
            echo 'ERROR: spoke1 service unexpectedly reaches spoke2 in the incident' >&2
            errors=$((errors + 1))
        }
        ! debug_dmvpn_ping spoke2 192.168.2.1 192.168.1.1 || {
            echo 'ERROR: spoke2 unexpectedly reaches spoke1 service in the incident' >&2
            errors=$((errors + 1))
        }
        debug_dmvpn_ping spoke2 192.168.2.1 192.168.3.1 || {
            echo 'ERROR: unaffected spoke2-to-spoke3 service path is down' >&2
            errors=$((errors + 1))
        }
        debug_dmvpn_ping spoke3 192.168.3.1 192.168.2.1 || {
            echo 'ERROR: unaffected spoke3-to-spoke2 service path is down' >&2
            errors=$((errors + 1))
        }
    fi

    (( errors == 0 ))
}
