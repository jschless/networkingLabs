#!/usr/bin/env bash
# Shared helpers for the ha-branch-dual-transport lab scripts.

HB_PREFIX=clab-ha-branch-dual-transport
# shellcheck disable=SC2034  # used by solution.sh
HB_NODES_CEOS=(br1 br2 acc1 acc2)
HB_NODES_ALL=(acc1 acc2 br1 br2 host1 hub inet mpls server)

hb_container() { printf '%s-%s\n' "$HB_PREFIX" "$1"; }

# hb_eos <node> "<exec command>" — one enable-mode command, output on stdout
hb_eos() {
    timeout -k 5 20 docker exec "$(hb_container "$1")" \
        Cli -p 15 -c enable -c "$2" 2>/dev/null
}

# hb_eos_config <node> — feed EOS CLI lines on stdin (starts in exec mode)
hb_eos_config() {
    { printf 'enable\nconfigure\n'; cat; printf 'end\n'; } \
        | timeout -k 5 30 docker exec -i "$(hb_container "$1")" Cli -p 15 >/dev/null
}

hb_sh() {
    local node=$1
    shift
    timeout -k 5 20 docker exec "$(hb_container "$node")" sh -c "$*"
}

hb_frr() {
    timeout -k 5 20 docker exec "$(hb_container "$1")" vtysh -c "$2" 2>/dev/null
}

hb_require_lab() {
    local actual expected
    actual=$(docker ps --format '{{.Names}}' | sed -n "s/^${HB_PREFIX}-//p" | LC_ALL=C sort)
    expected=$(printf '%s\n' "${HB_NODES_ALL[@]}" | LC_ALL=C sort)
    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: lab is not fully running. Deploy it first:" >&2
        echo "  ./scripts/lab.sh deploy ha-branch-dual-transport" >&2
        return 1
    fi
}

hb_write_memory() {
    hb_eos "$1" 'copy running-config startup-config' >/dev/null
}
