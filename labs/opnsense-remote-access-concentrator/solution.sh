#!/usr/bin/env bash
# Transactionally replace lab-owned OPNsense and client state, then grade it.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/opnsense-remote-access-concentrator/solution.sh' \
        '' \
        'Converge the disposable native OPNsense concentrator and both' \
        'per-deployment WireGuard clients, then run exact grading.'
}
case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$lab_dir/lab-lib.sh"

fw_backup=
developer_backup=
contractor_backup=
rollback_armed=false
hold_pid=

make_client_backup() {
    local node=$1 backup
    backup=$(docker exec "$RA_PREFIX-$node" bash -c '
        set -euo pipefail
        umask 077
        backup=$(mktemp -d /tmp/opnsense-ra-client.XXXXXX)
        chmod 700 "$backup"
        if [[ -d /run/opnsense-ra-lab ]]; then
            cp -a /run/opnsense-ra-lab "$backup/runtime"
        fi
        if ip link show wg0 >/dev/null 2>&1; then
            : >"$backup/wg0.exists"
            wg showconf wg0 >"$backup/wg0.conf"
            chmod 600 "$backup/wg0.conf"
            ip -o address show dev wg0 | awk "{print \$4}" >"$backup/addresses"
            ip -4 route show table main \
                | grep -E "(^|[[:space:]])dev wg0([[:space:]]|$)" \
                >"$backup/routes4" || true
            ip -6 route show table main \
                | grep -E "(^|[[:space:]])dev wg0([[:space:]]|$)" \
                >"$backup/routes6" || true
            ip -o link show dev wg0 | grep -q "<[^>]*UP[^>]*>" && : >"$backup/wg0.up" || true
        fi
        printf "%s\n" "$backup"
    ')
    [[ "$backup" =~ ^/tmp/opnsense-ra-client\.[[:alnum:]]{6}$ ]] || {
        echo "ERROR: client backup path was not safely bounded" >&2
        return 1
    }
    printf '%s\n' "$backup"
}

delete_client_backup() {
    local node=$1 backup=${2:-}
    [[ -z "$backup" ]] && return 0
    [[ "$backup" =~ ^/tmp/opnsense-ra-client\.[[:alnum:]]{6}$ ]] || return 1
    docker exec -i "$RA_PREFIX-$node" bash -s -- "$backup" <<'EOF' >/dev/null
set -euo pipefail
backup=$1
rm -rf "$backup/runtime"
rm -f "$backup/wg0.exists" "$backup/wg0.conf" "$backup/addresses" \
    "$backup/routes4" "$backup/routes6" "$backup/wg0.up"
rmdir "$backup"
EOF
}

restore_client_backup() {
    local node=$1 backup=${2:-}
    [[ -z "$backup" ]] && return 0
    [[ "$backup" =~ ^/tmp/opnsense-ra-client\.[[:alnum:]]{6}$ ]] || return 1
    docker exec -i "$RA_PREFIX-$node" bash -s -- "$backup" <<'EOF' >/dev/null
set -euo pipefail
backup=$1
ip link delete wg0 >/dev/null 2>&1 || true
rm -rf /run/opnsense-ra-lab
if [[ -d "$backup/runtime" ]]; then
    cp -a "$backup/runtime" /run/opnsense-ra-lab
fi
if [[ -f "$backup/wg0.exists" ]]; then
    ip link add wg0 type wireguard
    wg setconf wg0 "$backup/wg0.conf"
    while IFS= read -r address; do
        [[ -z "$address" ]] || ip address add "$address" dev wg0
    done <"$backup/addresses"
    [[ ! -f "$backup/wg0.up" ]] || ip link set wg0 up
    while IFS= read -r route; do
        [[ -z "$route" ]] && continue
        read -r -a route_args <<<"$route"
        ip -4 route replace "${route_args[@]}"
    done <"$backup/routes4"
    while IFS= read -r route; do
        [[ -z "$route" ]] && continue
        read -r -a route_args <<<"$route"
        ip -6 route replace "${route_args[@]}"
    done <"$backup/routes6"
fi
rm -rf "$backup/runtime"
rm -f "$backup/wg0.exists" "$backup/wg0.conf" "$backup/addresses" \
    "$backup/routes4" "$backup/routes6" "$backup/wg0.up"
rmdir "$backup"
EOF
}

prepare_client_identity() {
    local node=$1
    docker exec -i "$RA_PREFIX-$node" bash -s <<'EOF' >/dev/null
set -euo pipefail
umask 077
runtime=/run/opnsense-ra-lab
mkdir -p "$runtime"
chmod 700 "$runtime"
valid=false
if [[ -s "$runtime/private.key" && -s "$runtime/public.key" ]]; then
    derived=$(wg pubkey <"$runtime/private.key" 2>/dev/null || true)
    stored=$(<"$runtime/public.key")
    [[ "$derived" =~ ^[A-Za-z0-9+/]{43}=$ && "$derived" == "$stored" ]] && valid=true
fi
if [[ "$valid" != true ]]; then
    wg genkey >"$runtime/private.key"
    wg pubkey <"$runtime/private.key" >"$runtime/public.key"
fi
chmod 600 "$runtime/private.key" "$runtime/public.key"
EOF
}

configure_client() {
    local node=$1 address=$2 server_public=$3
    docker exec -i -e RA_CLIENT_ADDRESS="$address" -e RA_SERVER_PUBLIC="$server_public" \
        "$RA_PREFIX-$node" bash -s <<'EOF' >/dev/null
set -euo pipefail
umask 077
runtime=/run/opnsense-ra-lab
[[ "$RA_SERVER_PUBLIC" =~ ^[A-Za-z0-9+/]{43}=$ ]]
[[ -s "$runtime/private.key" && -s "$runtime/public.key" ]]
private=$(<"$runtime/private.key")
temporary="$runtime/wg0.conf.new"
printf '%s\n' \
    '[Interface]' \
    "Address = $RA_CLIENT_ADDRESS" \
    "PrivateKey = $private" \
    '' \
    '[Peer]' \
    "PublicKey = $RA_SERVER_PUBLIC" \
    'Endpoint = 203.0.113.2:51820' \
    'AllowedIPs = 10.70.10.0/24' \
    'PersistentKeepalive = 5' >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$runtime/wg0.conf"
chmod 600 "$runtime/wg0.conf"
ip link delete wg0 >/dev/null 2>&1 || true
wg-quick up "$runtime/wg0.conf"
EOF
}

rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
        hold_pid=
    fi
    if [[ "$rollback_armed" == true ]]; then
        restore_client_backup developer "$developer_backup" || rollback_status=1
        restore_client_backup contractor "$contractor_backup" || rollback_status=1
        ra_restore_fw_backup "$fw_backup" || rollback_status=1
    fi
    (( rollback_status == 0 )) \
        || echo "ERROR: one or more independent rollback legs failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

ra_require_tools
ra_require_containers
ra_ssh_ready || { echo "ERROR: OPNsense SSH is not ready" >&2; exit 1; }

fw_backup=$(ra_make_fw_backup)
rollback_armed=true
developer_backup=$(make_client_backup developer)
contractor_backup=$(make_client_backup contractor)

prepare_client_identity developer
prepare_client_identity contractor
developer_public=$(ra_client_public developer)
contractor_public=$(ra_client_public contractor)
ra_public_keys_ready \
    || { echo "ERROR: distinct client identities were not created safely" >&2; exit 1; }

ra_php base "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
[[ ${RA_SOLUTION_TEST_FAIL_AFTER_BASE:-0} != 1 ]] || false
ra_php server "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
ra_reload_base >/dev/null

# The base transaction reserves opt3 for wg0; registration activates it before
# its MVC policy is saved.
ra_php firewall "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
ra_ssh 'configctl filter reload' >/dev/null

server_public=$(ra_server_public)
ra_valid_public_key "$server_public" \
    || { echo "ERROR: concentrator public identity is unavailable" >&2; exit 1; }
configure_client developer 10.250.0.10/32 "$server_public"
configure_client contractor 10.250.0.20/32 "$server_public"

hold=${RA_SOLUTION_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo "ERROR: test hold must be an integer" >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

converged=false
for _attempt in $(seq 1 45); do
    if ra_tcp_expect developer 10.70.10.10 8443 corp-application \
        && ra_tcp_expect developer 10.70.10.20 22 jump-host \
        && ra_tcp_expect contractor 10.70.10.20 22 jump-host \
        && ra_tcp_denied contractor 10.70.10.10 8443; then
        converged=true
        break
    fi
    sleep 1
done
[[ "$converged" == true ]] \
    || { echo "ERROR: remote-access policy did not converge in the bounded wait" >&2; exit 1; }

"$lab_dir/check.sh" || {
    echo "ERROR: connectivity converged, but exact saved/live grading failed" >&2
    exit 1
}

# This is the transaction commit point. Cleanup each backup independently;
# never attempt a partial rollback after any backup has been deleted.
rollback_armed=false
trap - ERR EXIT INT TERM
cleanup_status=0
if ra_delete_fw_backup "$fw_backup"; then
    fw_backup=
else
    echo "ERROR: committed state is healthy, but firewall backup cleanup may remain at $fw_backup" >&2
    cleanup_status=1
fi
if delete_client_backup developer "$developer_backup"; then
    developer_backup=
else
    echo "ERROR: committed state is healthy, but developer backup cleanup may remain at $developer_backup" >&2
    cleanup_status=1
fi
if delete_client_backup contractor "$contractor_backup"; then
    contractor_backup=
else
    echo "ERROR: committed state is healthy, but contractor backup cleanup may remain at $contractor_backup" >&2
    cleanup_status=1
fi
(( cleanup_status == 0 )) || exit 1
echo "Healthy native OPNsense remote-access state applied, saved, and verified."
