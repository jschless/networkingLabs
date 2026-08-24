#!/usr/bin/env bash
# Generate/reuse PKI, replace every learned subtree, save, converge, and grade.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3-ipsec-capstone/solution.sh' \
        '' \
        'Generate or validate the private in-lab PKI, stream each identity into' \
        'its router without exposing secrets, replace all learned state, save,' \
        'converge, and require the complete checker.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
lab_dir=$(cd "$(dirname "$0")" && pwd)

cleanup_staging() {
    for router in hub spoke1 spoke2 spoke3; do
        docker exec "$prefix-$router" rm -rf /tmp/dmvpn-capstone-pki \
            >/dev/null 2>&1 || true
    done
}
trap cleanup_staging EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

normalize_commands() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        sed '/^[[:space:]]*$/d' | LC_ALL=C sort
}
interface_commands() {
    grep -E '^set interfaces ' | normalize_commands
}
management_interface_commands() {
    local router=$1 container_name bridge_label network_ref network_id metadata
    local v4_prefix v6_prefix
    local -a addresses
    container_name="$prefix-$router"
    bridge_label=$(docker inspect --format \
        '{{index .Config.Labels "clab-mgmt-net-bridge"}}' "$container_name" 2>/dev/null) || return 1
    [[ "$bridge_label" =~ ^br-([[:xdigit:]]{12})$ ]] || return 1
    network_ref=${BASH_REMATCH[1]}
    network_id=$(docker network inspect --format '{{.Id}}' "$network_ref" 2>/dev/null) || return 1
    [[ "$network_id" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    metadata=$(docker inspect --format \
        '{{range .NetworkSettings.Networks}}{{.NetworkID}}|{{.IPAddress}}|{{.IPPrefixLen}}|{{.GlobalIPv6Address}}|{{.GlobalIPv6PrefixLen}}{{println}}{{end}}' \
        "$container_name" 2>/dev/null | awk -F'|' -v network_id="$network_id" '
            $1 == network_id {
                matches++
                print $2 "/" $3
                print $4 "/" $5
            }
            END { if (matches != 1) exit 1 }
        ') || return 1
    mapfile -t addresses <<<"$metadata"
    [[ ${#addresses[@]} == 2 ]] || return 1
    [[ ${addresses[0]} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
    [[ ${addresses[1]} =~ ^[[:xdigit:]:]+/[0-9]{1,3}$ ]] || return 1
    v4_prefix=${addresses[0]##*/}
    v6_prefix=${addresses[1]##*/}
    (( 10#$v4_prefix <= 32 && 10#$v6_prefix <= 128 )) || return 1
    printf 'set interfaces ethernet eth0 address %s\n' "${addresses[0]}" "${addresses[1]}"
}

for node in br-wan ca hub spoke1 spoke2 spoke3; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo 'ERROR: the capstone is not fully deployed' >&2
        exit 1
    }
done

# Reject out-of-scope baseline changes; the learned protocol, PKI, and IPsec
# subtrees are intentionally replaced below.
for router in hub spoke1 spoke2 spoke3; do
    case "$router" in
        hub) wan=10.0.0.1; overlay=172.16.0.1; extra='' ;;
        spoke1) wan=10.0.0.11; overlay=172.16.0.11; extra=$'set interfaces dummy dum0 address 192.168.1.1/24\nset interfaces dummy dum0 description "Service LAN 1"' ;;
        spoke2) wan=10.0.0.12; overlay=172.16.0.12; extra=$'set interfaces dummy dum0 address 192.168.2.1/24\nset interfaces dummy dum0 description "Service LAN 2"' ;;
        spoke3) wan=10.0.0.13; overlay=172.16.0.13; extra=$'set interfaces dummy dum0 address 192.168.3.1/24\nset interfaces dummy dum0 description "Service LAN 3"' ;;
    esac
    management=$(management_interface_commands "$router") || {
        echo "ERROR: $router ContainerLab management metadata is missing or ambiguous" >&2
        exit 1
    }
    expected=$(cat <<EOF | normalize_commands
$extra
$management
set interfaces ethernet eth1 address $wan/24
set interfaces ethernet eth1 description "WAN NBMA"
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces loopback lo
set interfaces tunnel tun0 address $overlay/32
set interfaces tunnel tun0 description "mGRE encrypted Phase 3 $router"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 mtu 1400
set interfaces tunnel tun0 source-interface eth1
EOF
)
    live=$(docker exec "$prefix-$router" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null)
    saved=$(docker exec "$prefix-$router" \
        /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null)
    [[ "$(interface_commands <<<"$live")" == "$expected" ]] || {
        echo "ERROR: $router has out-of-scope live interface pollution" >&2
        exit 1
    }
    [[ "$(interface_commands <<<"$saved")" == "$expected" ]] || {
        echo "ERROR: $router has out-of-scope saved interface pollution" >&2
        exit 1
    }
    if grep -qE '^set protocols (bgp|isis|rip)([[:space:]]|$)' <<<"$live" \
        || grep -qE '^set protocols (bgp|isis|rip)([[:space:]]|$)' <<<"$saved"; then
        echo "ERROR: $router has out-of-scope routing-protocol pollution" >&2
        exit 1
    fi
done

timeout 20 docker exec "$prefix-ca" /opt/dmvpn-pki/init-ca.sh >/dev/null
for router in hub spoke1 spoke2 spoke3; do
    timeout 25 docker exec "$prefix-ca" /opt/dmvpn-pki/issue-router.sh \
        "$router" "$router.dmvpn.lab" >/dev/null
done
timeout 30 docker exec "$prefix-ca" /opt/dmvpn-pki/validate-pki.sh --all >/dev/null

stream_identity() {
    local router=$1
    docker exec "$prefix-$router" bash -c \
        'umask 077; rm -rf /tmp/dmvpn-capstone-pki; install -d -m 0700 /tmp/dmvpn-capstone-pki' \
        >/dev/null
    docker exec "$prefix-ca" tar -C /lab/pki -cf - \
        ca/dmvpn-ca.pem "certs/$router.pem" "private/$router.key" | \
        docker exec -i "$prefix-$router" tar -C /tmp/dmvpn-capstone-pki -xf -
    # The apply helper runs as VyOS admin (primary group users). Keep the
    # secret tree owner-only while allowing that exact identity to traverse,
    # validate, consume, and remove its runtime staging directory.
    docker exec "$prefix-$router" bash -c \
        'chown -R admin:users /tmp/dmvpn-capstone-pki &&
         find /tmp/dmvpn-capstone-pki -type d -exec chmod 0700 {} + &&
         find /tmp/dmvpn-capstone-pki -type f -exec chmod 0600 {} +'
}

# Configure highest-ranked responders first; only the lower-ranked endpoint of
# each pair initiates, so duplicate IKE/CHILD SAs cannot race into existence.
for router in spoke3 spoke2 spoke1 hub; do
    stream_identity "$router"
    if ! timeout 45 docker exec "$prefix-$router" su - admin -c \
        '/bin/vbash /opt/dmvpn-capstone/apply-solution.sh' >/dev/null 2>&1; then
        echo "ERROR: secret-safe learned-state application failed on $router" >&2
        exit 1
    fi
done

crypto_exact() {
    local router ike child state policy
    for router in hub spoke1 spoke2 spoke3; do
        ike=$(docker exec "$prefix-$router" bash -lc \
            "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true)
        child=$(docker exec "$prefix-$router" bash -lc \
            "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true)
        state=$(docker exec "$prefix-$router" ip -s xfrm state 2>/dev/null || true)
        policy=$(docker exec "$prefix-$router" ip -s xfrm policy 2>/dev/null || true)
        [[ "$(grep -Ec '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$ike" || true)" == 3 ]] || return 1
        [[ "$(grep -Ec '^[^[:space:]]+[[:space:]]+up[[:space:]]' <<<"$child" || true)" == 3 ]] || return 1
        [[ "$(grep -Ec '^src[[:space:]]' <<<"$state" || true)" == 6 ]] || return 1
        [[ "$(grep -Ec '^src .* proto gre([[:space:]]|$)' <<<"$policy" || true)" == 6 ]] || return 1
    done
}

converged=false
complete_samples=0
for _attempt in $(seq 1 75); do
    sample=true
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    [[ "$(grep -Ec '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.1[123][[:space:]]' <<<"$hub_nhrp" || true)" == 3 ]] || sample=false
    [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 3 ]] || sample=false
    crypto_exact || sample=false
    if [[ "$sample" == true ]]; then
        ((complete_samples += 1))
    else
        complete_samples=0
    fi
    if (( complete_samples >= 2 )); then converged=true; break; fi
    sleep 1
done
[[ "$converged" == true ]] || {
    echo 'ERROR: exact DMVPN and 3/3/6/6 crypto state did not converge twice within the bound' >&2
    exit 1
}

"$lab_dir/seed-shortcuts.sh" >/dev/null
if ! timeout 240 "$lab_dir/check.sh"; then
    echo 'ERROR: basic convergence succeeded, but the complete checker failed' >&2
    exit 1
fi
echo 'Healthy certificate-protected Phase 3 state applied, saved, and completely verified.'
