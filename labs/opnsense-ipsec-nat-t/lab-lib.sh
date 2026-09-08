#!/usr/bin/env bash
# Shared host-side helpers for the OPNsense NAT-T lab.

NATT_PREFIX=clab-opnsense-ipsec-nat-t
NATT_HQ_PORT=2301
NATT_BRANCH_PORT=2302
NATT_PASSWORD=opnsense
NATT_SSH_OPTIONS=(
    -o BatchMode=no
    -o ConnectTimeout=5
    -o ConnectionAttempts=1
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
)

natt_require_tools() {
    local tool
    for tool in docker ssh sshpass timeout; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "ERROR: required host command is unavailable: $tool" >&2
            return 1
        }
    done
}

natt_require_containers() {
    local node
    for node in nat-cpe hq-host branch-host; do
        [[ "$(docker inspect --format '{{.State.Running}}' "$NATT_PREFIX-$node" 2>/dev/null)" == true ]] || {
            echo "ERROR: opnsense-ipsec-nat-t is not fully deployed" >&2
            return 1
        }
    done
}

natt_ssh() {
    local port=$1
    shift
    SSHPASS=$NATT_PASSWORD sshpass -e ssh "${NATT_SSH_OPTIONS[@]}" \
        -p "$port" root@127.0.0.1 "$@"
}

natt_ssh_ready() {
    natt_ssh "$1" true >/dev/null 2>&1
}

# OPNsense root uses csh. Stream POSIX shell fragments explicitly so helpers
# never depend on the login shell's parsing rules.
natt_sh() {
    local port=$1
    shift
    natt_ssh "$port" /bin/sh -s -- "$@"
}

natt_php() {
    local port=$1 role=$2 phase=$3 file=$4
    if [[ -n "$phase" ]]; then
        natt_ssh "$port" "env NATT_ROLE=$role NATT_PHASE=$phase php" <"$file"
    else
        natt_ssh "$port" "env NATT_ROLE=$role php" <"$file"
    fi
}

natt_reload_base() {
    local port=$1
    natt_sh "$port" <<'EOF'
configctl interface reconfigure opt1 &&
configctl interface reconfigure opt2 &&
configctl interface routes configure &&
configctl template reload OPNsense/IPsec &&
configctl ipsec restart &&
configctl interface invoke registration
EOF
}

natt_reload_restored() {
    local port=$1
    natt_sh "$port" <<'EOF'
configctl interface reconfigure opt1 >/dev/null 2>&1 || true
configctl interface reconfigure opt2 >/dev/null 2>&1 || true
configctl interface routes configure >/dev/null 2>&1 || true
configctl template reload OPNsense/IPsec >/dev/null 2>&1 || true
configctl ipsec restart >/dev/null 2>&1 || true
configctl interface invoke registration >/dev/null 2>&1 || true
configctl filter reload >/dev/null 2>&1 || true
EOF
}

natt_delete_fault_rules() {
    local node="$NATT_PREFIX-nat-cpe"
    while docker exec "$node" iptables -C FORWARD -p udp --sport 4500 \
        -m comment --comment natt-lab-fault -j DROP >/dev/null 2>&1; do
        docker exec "$node" iptables -D FORWARD -p udp --sport 4500 \
            -m comment --comment natt-lab-fault -j DROP >/dev/null
    done
    while docker exec "$node" iptables -C FORWARD -p udp --dport 4500 \
        -m comment --comment natt-lab-fault -j DROP >/dev/null 2>&1; do
        docker exec "$node" iptables -D FORWARD -p udp --dport 4500 \
            -m comment --comment natt-lab-fault -j DROP >/dev/null
    done
}

natt_fault_count() {
    docker exec "$NATT_PREFIX-nat-cpe" iptables -S FORWARD 2>/dev/null \
        | grep -c -- '--comment natt-lab-fault' || true
}

natt_restart_ipsec() {
    natt_ssh "$NATT_HQ_PORT" 'configctl ipsec restart' >/dev/null
    natt_ssh "$NATT_BRANCH_PORT" 'configctl ipsec restart' >/dev/null
}

natt_protected_ready() {
    docker exec "$NATT_PREFIX-hq-host" ping -c 1 -W 1 10.20.1.10 >/dev/null 2>&1 \
        && docker exec "$NATT_PREFIX-branch-host" ping -c 1 -W 1 10.10.1.10 >/dev/null 2>&1
}
