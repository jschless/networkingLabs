#!/usr/bin/env bash
# Shared, read-only state contract used by lifecycle helpers.

DEBUG_GRE_PREFIX=clab-debug-gre-basics

debug_gre_container() {
    printf '%s-%s\n' "$DEBUG_GRE_PREFIX" "$1"
}

debug_gre_running() {
    [[ "$(docker inspect --format '{{.State.Running}}' \
        "$(debug_gre_container "$1")" 2>/dev/null)" == true ]]
}

debug_gre_eos() {
    local node=$1 command=$2
    docker exec "$(debug_gre_container "$node")" \
        Cli -p 15 -c enable -c "$command" 2>/dev/null
}

debug_gre_node() {
    local node=$1 command=$2
    docker exec "$(debug_gre_container "$node")" sh -c "$command" 2>/dev/null
}

debug_gre_mgmt_facts() {
    local node=$1 raw address prefix gateway subnet
    raw=$(docker inspect --format \
        '{{with index .NetworkSettings.Networks "clab"}}{{.IPAddress}} {{.IPPrefixLen}} {{.Gateway}}{{end}}' \
        "$(debug_gre_container "$node")" 2>/dev/null) || return 1
    read -r address prefix gateway <<<"$raw"
    [[ -n "$address" && "$prefix" =~ ^[0-9]+$ && -n "$gateway" ]] || return 1
    subnet=$(python3 -c \
        'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' \
        "$address/$prefix") || return 1
    printf '%s/%s %s %s\n' "$address" "$prefix" "$gateway" "$subnet"
}

debug_gre_linux_mgmt_address() {
    debug_gre_node "$1" \
        "ip -4 -o address show dev eth0 scope global | awk '{print \$2, \$4}' | sort"
}

debug_gre_linux_mgmt_routes() {
    debug_gre_node "$1" \
        "ip -4 route show table main | grep ' dev eth0' | sed -E 's/[[:space:]]+\$//' | sort"
}

debug_gre_linux_expected_mgmt_routes() {
    local node=$1 cidr gateway subnet address
    read -r cidr gateway subnet <<<"$(debug_gre_mgmt_facts "$node")" || return 1
    address=${cidr%/*}
    case "$node" in
        host-a|host-b)
            printf '%s dev eth0 proto kernel scope link src %s\n' "$subnet" "$address"
            ;;
        internet)
            printf '%s dev eth0 proto kernel scope link src %s\n' "$subnet" "$address"
            printf 'default via %s dev eth0\n' "$gateway"
            ;;
        *) return 2 ;;
    esac
}

debug_gre_linux_mgmt_exact() {
    local node=$1 cidr _gateway _subnet
    read -r cidr _gateway _subnet <<<"$(debug_gre_mgmt_facts "$node")" || return 1
    [[ "$(debug_gre_linux_mgmt_address "$node")" == "eth0 $cidr" ]] \
        && [[ "$(debug_gre_linux_mgmt_routes "$node")" == \
            "$(debug_gre_linux_expected_mgmt_routes "$node")" ]]
}

debug_gre_clean_section() {
    sed -E '/^[[:space:]]*(!|$)/d; s/\r$//; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

debug_gre_interface_names() {
    local node=$1 plane=${2:-running} command='show running-config'
    [[ "$plane" == running ]] || command='show startup-config'
    debug_gre_eos "$node" "$command" \
        | sed -nE 's/^interface ([^[:space:]]+).*/\1/p' \
        | LC_ALL=C sort
}

debug_gre_routes() {
    local node=$1 plane=${2:-running} command='show running-config'
    [[ "$plane" == running ]] || command='show startup-config'
    debug_gre_eos "$node" "$command" \
        | sed -nE '/^ip route vrf /d; /^ip route /p' \
        | LC_ALL=C sort
}

debug_gre_vrf_routes() {
    local node=$1 plane=${2:-running} command='show running-config'
    [[ "$plane" == running ]] || command='show startup-config'
    debug_gre_eos "$node" "$command" \
        | sed -nE '/^ip route vrf /p' \
        | LC_ALL=C sort
}

debug_gre_section() {
    local node=$1 interface=$2 plane=${3:-running}
    if [[ "$plane" == running ]]; then
        debug_gre_eos "$node" "show running-config interfaces $interface" \
            | debug_gre_clean_section
    else
        debug_gre_eos "$node" 'show startup-config' \
            | awk -v wanted="$interface" '
                /^interface / {
                    if (inside && $2 != wanted) exit
                    if ($2 == wanted) inside=1
                }
                inside { print }
                inside && /^!/ { exit }
            ' | debug_gre_clean_section
    fi
}

debug_gre_tunnel_expected() {
    local node=$1 mode=$2
    case "$node:$mode" in
        gw-a:incident|gw-a:healthy) printf '%s\n' '203.0.113.6' ;;
        gw-b:incident) printf '%s\n' '192.168.1.1' ;;
        gw-b:healthy) printf '%s\n' '203.0.113.1' ;;
        *) return 2 ;;
    esac
}

debug_gre_interface_allowed() {
    local node=$1 interface=$2 mode=$3 plane=${4:-running}
    local destination section expected
    destination=$(debug_gre_tunnel_expected "$node" "$mode") || return 1
    section=$(debug_gre_section "$node" "$interface" "$plane") || return 1

    case "$node:$interface" in
        gw-a:Loopback0)
            expected=$'interface Loopback0\nip address 10.0.0.1/32'
            ;;
        gw-b:Loopback0)
            expected=$'interface Loopback0\nip address 10.0.0.2/32'
            ;;
        gw-a:Ethernet1)
            expected=$'interface Ethernet1\ndescription to host-a LAN-A\nno switchport\nip address 192.168.1.1/24'
            ;;
        gw-a:Ethernet2)
            expected=$'interface Ethernet2\ndescription to internet WAN-A\nno switchport\nip address 203.0.113.1/30'
            ;;
        gw-b:Ethernet1)
            expected=$'interface Ethernet1\ndescription to internet WAN-B\nno switchport\nip address 203.0.113.6/30'
            ;;
        gw-b:Ethernet2)
            expected=$'interface Ethernet2\ndescription to host-b LAN-B\nno switchport\nip address 192.168.2.1/24'
            ;;
        gw-a:Tunnel0)
            expected=$(printf '%s\n' \
                'interface Tunnel0' \
                'description GRE to Site B' \
                'ip address 172.16.0.1/30' \
                'tunnel source interface Ethernet2' \
                "tunnel destination $destination")
            ;;
        gw-b:Tunnel0)
            expected=$(printf '%s\n' \
                'interface Tunnel0' \
                'description GRE to Site A' \
                'ip address 172.16.0.2/30' \
                'tunnel source interface Ethernet1' \
                "tunnel destination $destination")
            ;;
        *) return 2 ;;
    esac

    [[ "$section" == "$expected" ]]
}

debug_gre_interface_up() {
    local node=$1 interface=$2 detail
    detail=$(debug_gre_eos "$node" "show interfaces $interface") || return 1
    grep -qE "^[[:space:]]*${interface} is up, line protocol is up([[:space:]]|\\(|$)" \
        <<<"$detail"
}

debug_gre_saved_exact() {
    local node=$1 interfaces routes vrf_routes saved_config interface
    interfaces=$(debug_gre_interface_names "$node" saved \
        | grep -vx 'Management0' || true)
    [[ "$interfaces" == $'Ethernet1\nEthernet2\nLoopback0\nTunnel0' ]] || return 1
    for interface in Loopback0 Ethernet1 Ethernet2 Tunnel0; do
        debug_gre_interface_allowed "$node" "$interface" incident saved || return 1
    done
    routes=$(debug_gre_routes "$node" saved)
    case "$node" in
        gw-a)
            [[ "$routes" == \
                $'ip route 0.0.0.0/0 203.0.113.2\nip route 192.168.2.0/24 172.16.0.2' ]] \
                || return 1
            ;;
        gw-b)
            [[ "$routes" == \
                $'ip route 0.0.0.0/0 203.0.113.5\nip route 192.168.1.0/24 172.16.0.1' ]] \
                || return 1
            ;;
        *) return 2 ;;
    esac
    vrf_routes=$(debug_gre_vrf_routes "$node" saved)
    [[ -z "$vrf_routes" ]] || return 1
    saved_config=$(debug_gre_eos "$node" 'show startup-config') || return 1
    ! grep -qE '^router[[:space:]]' <<<"$saved_config"
}

debug_gre_runtime_detail_exact() {
    local node=$1 mode=$2 source destination detail
    destination=$(debug_gre_tunnel_expected "$node" "$mode") || return 1
    case "$node" in
        gw-a) source='203\.0\.113\.1' ;;
        gw-b) source='203\.0\.113\.6' ;;
        *) return 2 ;;
    esac
    detail=$(debug_gre_eos "$node" 'show interfaces Tunnel0') || return 1
    grep -qiE "^[[:space:]]*Tunnel source ${source}, destination ${destination//./\\.}[[:space:]]*$" \
        <<<"$detail"
}

debug_gre_verify_state() {
    local mode=$1 errors=0 node interface routes vrf_routes running_config detail
    local actual_nodes image addresses host_routes transit_routes
    [[ "$mode" == incident || "$mode" == healthy ]] || return 2

    for node in gw-a gw-b host-a host-b internet; do
        if ! debug_gre_running "$node"; then
            echo "ERROR: $node is not running" >&2
            errors=$((errors + 1))
        fi
    done
    (( errors == 0 )) || return 1

    actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
        's/^clab-debug-gre-basics-//p' | LC_ALL=C sort)
    if [[ "$actual_nodes" != $'gw-a\ngw-b\nhost-a\nhost-b\ninternet' ]]; then
        echo 'ERROR: target node inventory is not the exact five-node topology' >&2
        errors=$((errors + 1))
    fi
    for node in gw-a gw-b; do
        image=$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_gre_container "$node")" 2>/dev/null || true)
        if [[ "$image" != 'ceos:4.35.2F' ]]; then
            echo "ERROR: $node is not using exact ceos:4.35.2F" >&2
            errors=$((errors + 1))
        fi
    done
    for node in host-a host-b internet; do
        image=$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_gre_container "$node")" 2>/dev/null || true)
        if [[ "$image" != 'ops-lab:local' ]]; then
            echo "ERROR: $node is not using exact ops-lab:local" >&2
            errors=$((errors + 1))
        fi
        if ! debug_gre_linux_mgmt_exact "$node"; then
            echo "ERROR: $node generated eth0 address/route inventory is polluted" >&2
            errors=$((errors + 1))
        fi
    done

    addresses=$(debug_gre_node host-a \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
    [[ "$addresses" == 'eth1 192.168.1.10/24' ]] || {
        echo 'ERROR: host-a data-plane address inventory is polluted' >&2
        errors=$((errors + 1))
    }
    addresses=$(debug_gre_node host-b \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
    [[ "$addresses" == 'eth1 192.168.2.10/24' ]] || {
        echo 'ERROR: host-b data-plane address inventory is polluted' >&2
        errors=$((errors + 1))
    }
    host_routes=$(debug_gre_node host-a \
        "ip -4 route show table main | grep -v ' dev eth0' | sort")
    if [[ "$(wc -l <<<"$host_routes" | tr -d ' ')" != 2 ]] \
        || ! grep -qE '^default via 192\.168\.1\.1 dev eth1([[:space:]]|$)' <<<"$host_routes" \
        || ! grep -qE '^192\.168\.1\.0/24 dev eth1 proto kernel scope link src 192\.168\.1\.10([[:space:]]|$)' <<<"$host_routes"; then
        echo 'ERROR: host-a route inventory is polluted' >&2
        errors=$((errors + 1))
    fi
    host_routes=$(debug_gre_node host-b \
        "ip -4 route show table main | grep -v ' dev eth0' | sort")
    if [[ "$(wc -l <<<"$host_routes" | tr -d ' ')" != 2 ]] \
        || ! grep -qE '^default via 192\.168\.2\.1 dev eth1([[:space:]]|$)' <<<"$host_routes" \
        || ! grep -qE '^192\.168\.2\.0/24 dev eth1 proto kernel scope link src 192\.168\.2\.10([[:space:]]|$)' <<<"$host_routes"; then
        echo 'ERROR: host-b route inventory is polluted' >&2
        errors=$((errors + 1))
    fi

    addresses=$(debug_gre_node internet \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
    [[ "$addresses" == $'eth1 203.0.113.2/30\neth2 203.0.113.5/30' ]] || {
        echo 'ERROR: internet data-plane address inventory is polluted' >&2
        errors=$((errors + 1))
    }
    [[ "$(debug_gre_node internet 'sysctl -n net.ipv4.ip_forward')" == 1 ]] || {
        echo 'ERROR: internet IPv4 forwarding is not enabled' >&2
        errors=$((errors + 1))
    }
    transit_routes=$(debug_gre_node internet \
        "ip -4 route show table main | grep -v ' dev eth0' | sort")
    if [[ "$(wc -l <<<"$transit_routes" | tr -d ' ')" != 2 ]] \
        || ! grep -qE '^203\.0\.113\.0/30 dev eth1 proto kernel scope link src 203\.0\.113\.2([[:space:]]|$)' <<<"$transit_routes" \
        || ! grep -qE '^203\.0\.113\.4/30 dev eth2 proto kernel scope link src 203\.0\.113\.5([[:space:]]|$)' <<<"$transit_routes"; then
        echo 'ERROR: internet route inventory is polluted' >&2
        errors=$((errors + 1))
    fi

    [[ "$(debug_gre_node gw-a 'cat /tmp/debug-gre-basics-eos-forward.ready')" == 'ready:eth1' ]] || {
        echo 'ERROR: gw-a forwarding readiness marker is not exact' >&2
        errors=$((errors + 1))
    }
    [[ "$(debug_gre_node gw-b 'cat /tmp/debug-gre-basics-eos-forward.ready')" == 'ready:eth2' ]] || {
        echo 'ERROR: gw-b forwarding readiness marker is not exact' >&2
        errors=$((errors + 1))
    }
    if debug_gre_node gw-a \
        'iptables -w 1 -C EOS_FORWARD -i eth1 -j DROP' >/dev/null; then
        echo 'ERROR: gw-a target LAN-ingress DROP remains active' >&2
        errors=$((errors + 1))
    fi
    if debug_gre_node gw-b \
        'iptables -w 1 -C EOS_FORWARD -i eth2 -j DROP' >/dev/null; then
        echo 'ERROR: gw-b target LAN-ingress DROP remains active' >&2
        errors=$((errors + 1))
    fi

    for node in gw-a gw-b; do
        if [[ "$(debug_gre_interface_names "$node")" != \
            $'Ethernet1\nEthernet2\nLoopback0\nManagement0\nTunnel0' ]]; then
            echo "ERROR: $node has unexpected configured interfaces" >&2
            errors=$((errors + 1))
        fi
        for interface in Loopback0 Ethernet1 Ethernet2 Tunnel0; do
            if ! debug_gre_interface_allowed "$node" "$interface" "$mode"; then
                echo "ERROR: $node $interface differs from the exact $mode contract" >&2
                errors=$((errors + 1))
            fi
            if ! debug_gre_interface_up "$node" "$interface"; then
                echo "ERROR: $node $interface is not operationally up/up" >&2
                errors=$((errors + 1))
            fi
        done
        vrf_routes=$(debug_gre_vrf_routes "$node")
        if [[ -n "$vrf_routes" ]]; then
            echo "ERROR: $node running VRF-route inventory is polluted" >&2
            errors=$((errors + 1))
        fi
        vrf_routes=$(debug_gre_vrf_routes "$node" saved)
        if [[ -n "$vrf_routes" ]]; then
            echo "ERROR: $node saved VRF-route inventory is polluted" >&2
            errors=$((errors + 1))
        fi
        if ! debug_gre_saved_exact "$node"; then
            echo "ERROR: $node saved startup configuration is not the exact incident" >&2
            errors=$((errors + 1))
        fi
        running_config=$(debug_gre_eos "$node" 'show running-config')
        if grep -qE '^router[[:space:]]' <<<"$running_config"; then
            echo "ERROR: $node has an unexpected dynamic-routing process" >&2
            errors=$((errors + 1))
        fi
        if ! debug_gre_runtime_detail_exact "$node" "$mode"; then
            echo "ERROR: $node runtime Tunnel0 source/destination differs from $mode" >&2
            errors=$((errors + 1))
        fi
    done

    routes=$(debug_gre_routes gw-a)
    if [[ "$routes" != $'ip route 0.0.0.0/0 203.0.113.2\nip route 192.168.2.0/24 172.16.0.2' ]]; then
        echo "ERROR: gw-a static-route inventory is polluted" >&2
        errors=$((errors + 1))
    fi
    routes=$(debug_gre_routes gw-b)
    if [[ "$routes" != $'ip route 0.0.0.0/0 203.0.113.5\nip route 192.168.1.0/24 172.16.0.1' ]]; then
        echo "ERROR: gw-b static-route inventory is polluted" >&2
        errors=$((errors + 1))
    fi

    if [[ "$mode" == healthy ]]; then
        for node in gw-a gw-b; do
            detail=$(debug_gre_eos "$node" 'show interfaces Tunnel0')
            if grep -qiE 'recursive route resolution loop|resolved over another tunnel' \
                <<<"$detail"; then
                echo "ERROR: $node still reports recursive tunnel resolution" >&2
                errors=$((errors + 1))
            fi
        done
    else
        detail=$(debug_gre_eos gw-b 'show interfaces Tunnel0')
        if ! grep -qiE 'recursive route resolution loop|resolved over another tunnel' \
            <<<"$detail"; then
            echo "ERROR: gw-b does not show the intended recursive incident" >&2
            errors=$((errors + 1))
        fi
    fi

    (( errors == 0 ))
}
