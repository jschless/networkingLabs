#!/usr/bin/env bash
# Shared host-side helpers for the OPNsense remote-access lab.

RA_PREFIX=clab-opnsense-remote-access-concentrator
RA_SSH_PORT=2401
RA_PASSWORD=opnsense
RA_SSH_OPTIONS=(
    -o BatchMode=no
    -o ConnectTimeout=5
    -o ConnectionAttempts=1
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
)

ra_require_tools() {
    local tool
    for tool in docker ssh sshpass timeout; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "ERROR: required host command is unavailable: $tool" >&2
            return 1
        }
    done
}

ra_require_containers() {
    local node
    for node in developer contractor corp-app jump-host; do
        [[ "$(docker inspect --format '{{.State.Running}}' "$RA_PREFIX-$node" 2>/dev/null)" == true ]] || {
            echo "ERROR: opnsense-remote-access-concentrator is not fully deployed" >&2
            return 1
        }
    done
}

ra_ssh() {
    SSHPASS=$RA_PASSWORD sshpass -e ssh "${RA_SSH_OPTIONS[@]}" \
        -p "$RA_SSH_PORT" root@127.0.0.1 "$@"
}

ra_ssh_ready() {
    ra_ssh true >/dev/null 2>&1
}

# OPNsense root uses csh. Stream POSIX fragments through /bin/sh explicitly.
ra_sh() {
    ra_ssh /bin/sh -s -- "$@"
}

ra_valid_public_key() {
    [[ ${1:-} =~ ^[A-Za-z0-9+/]{43}=$ ]]
}

ra_client_public() {
    docker exec "$RA_PREFIX-$1" sh -c \
        'test -f /run/opnsense-ra-lab/public.key && cat /run/opnsense-ra-lab/public.key' \
        2>/dev/null || true
}

ra_public_keys_ready() {
    local developer_public contractor_public
    developer_public=$(ra_client_public developer)
    contractor_public=$(ra_client_public contractor)
    ra_valid_public_key "$developer_public" \
        && ra_valid_public_key "$contractor_public" \
        && [[ "$developer_public" != "$contractor_public" ]]
}

ra_php() {
    local phase=$1 developer_public=${2:-invalid} contractor_public=${3:-invalid} file=$4
    ra_valid_public_key "$developer_public" || developer_public=invalid
    ra_valid_public_key "$contractor_public" || contractor_public=invalid
    ra_ssh "env RA_PHASE=$phase RA_DEV_PUBLIC=$developer_public RA_CONTRACTOR_PUBLIC=$contractor_public php" <"$file"
}

ra_reload_base() {
    ra_sh <<'EOF'
configctl interface reconfigure opt1 &&
configctl interface reconfigure opt2 &&
configctl template reload OPNsense/Wireguard &&
configctl wireguard configure &&
configctl interface invoke registration
EOF
}

ra_reload_wireguard() {
    ra_sh <<'EOF'
configctl template reload OPNsense/Wireguard &&
configctl wireguard configure
EOF
}

ra_reload_restored() {
    ra_sh <<'EOF'
configctl interface reconfigure opt1 >/dev/null 2>&1 || true
configctl interface reconfigure opt2 >/dev/null 2>&1 || true
configctl template reload OPNsense/Wireguard >/dev/null 2>&1 || true
configctl wireguard configure >/dev/null 2>&1 || true
configctl interface invoke registration >/dev/null 2>&1 || true
configctl filter reload >/dev/null 2>&1 || true
EOF
}

ra_make_fw_backup() {
    local backup
    backup=$(ra_sh <<'EOF'
umask 077
backup_dir=$(mktemp -d /tmp/opnsense-ra.XXXXXX) || exit 1
cp -p /conf/config.xml "$backup_dir/config.xml" || exit 1
printf '%s\n' "$backup_dir"
EOF
)
    [[ "$backup" =~ ^/tmp/opnsense-ra\.[[:alnum:]]{6}$ ]] || {
        echo "ERROR: firewall backup path was not safely bounded" >&2
        return 1
    }
    printf '%s\n' "$backup"
}

ra_delete_fw_backup() {
    local backup=${1:-}
    [[ -z "$backup" ]] && return 0
    [[ "$backup" =~ ^/tmp/opnsense-ra\.[[:alnum:]]{6}$ ]] || return 1
    ra_sh "$backup" <<'EOF' >/dev/null
backup=$1
rm -f "$backup/config.xml" && rmdir "$backup"
EOF
}

ra_restore_fw_backup() {
    local backup=${1:-}
    [[ -z "$backup" ]] && return 0
    [[ "$backup" =~ ^/tmp/opnsense-ra\.[[:alnum:]]{6}$ ]] || return 1
    ra_sh "$backup" <<'EOF' >/dev/null
backup=$1
test -f "$backup/config.xml" &&
    cp -p "$backup/config.xml" /conf/config.xml &&
    rm -f "$backup/config.xml" &&
    rmdir "$backup"
EOF
    ra_reload_restored
}

ra_tcp_expect() {
    local node=$1 address=$2 port=$3 expected=$4
    docker exec "$RA_PREFIX-$node" timeout 4 bash -c '
        exec 3<>"/dev/tcp/$1/$2"
        IFS= read -r -t 2 response <&3
        [[ "$response" == "$3" ]]
    ' bash "$address" "$port" "$expected" >/dev/null 2>&1
}

ra_tcp_denied() {
    ! docker exec "$RA_PREFIX-$1" timeout 3 bash -c \
        'exec 3<>"/dev/tcp/$1/$2"' bash "$2" "$3" >/dev/null 2>&1
}

ra_recent_timestamp() {
    local timestamp=${1:-} now
    now=$(date +%s)
    [[ "$timestamp" =~ ^[0-9]+$ ]] \
        && (( timestamp > 0 && now >= timestamp && now - timestamp <= 180 ))
}

ra_server_public() {
    ra_ssh '/usr/bin/wg show wg0 public-key' 2>/dev/null || true
}

ra_fault_ready() {
    local developer_public=$1 contractor_public=$2 allowed latest
    allowed=$(ra_ssh '/usr/bin/wg show wg0 allowed-ips' 2>/dev/null || true)
    latest=$(ra_ssh '/usr/bin/wg show wg0 latest-handshakes' 2>/dev/null || true)
    [[ "$(awk -v key="$developer_public" '$1 == key {print $2}' <<<"$allowed")" == "10.250.0.10/32" ]] \
        && [[ "$(awk -v key="$contractor_public" '$1 == key {print $2}' <<<"$allowed")" == "10.250.0.21/32" ]] \
        && ra_recent_timestamp "$(awk -v key="$contractor_public" '$1 == key {print $2}' <<<"$latest")" \
        && docker exec "$RA_PREFIX-contractor" ping -c 1 -W 1 203.0.113.2 >/dev/null 2>&1 \
        && ra_tcp_expect developer 10.70.10.10 8443 corp-application \
        && ra_tcp_expect developer 10.70.10.20 22 jump-host \
        && ra_tcp_denied contractor 10.70.10.20 22
}

ra_revoked_ready() {
    local developer_public=$1 peers latest
    peers=$(ra_ssh '/usr/bin/wg show wg0 peers' 2>/dev/null || true)
    latest=$(ra_ssh '/usr/bin/wg show wg0 latest-handshakes' 2>/dev/null || true)
    [[ "$peers" == "$developer_public" ]] \
        && ra_recent_timestamp "$(awk -v key="$developer_public" '$1 == key {print $2}' <<<"$latest")" \
        && ra_tcp_expect developer 10.70.10.10 8443 corp-application \
        && ra_tcp_expect developer 10.70.10.20 22 jump-host \
        && ra_tcp_denied contractor 10.70.10.20 22 \
        && ra_tcp_denied contractor 10.70.10.10 8443
}
