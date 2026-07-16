#!/usr/bin/env bash
# Shared lifecycle helpers for OPNsense QEMU/KVM labs.
#
# The base disk is deliberately local-only.  OPNsense is free software, but a
# VM image is a large binary and does not belong in the Git repository.

set -euo pipefail

OPNSENSE_BASE_IMAGE="${OPNSENSE_BASE_IMAGE:-/var/lib/containerlab/opnsense/opnsense-base.qcow2}"

opnsense_require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Run with sudo: QEMU needs tap interfaces and KVM access." >&2
        exit 1
    fi
}

opnsense_require_host() {
    if [[ "$(uname -m)" != "x86_64" || ! -e /dev/kvm ]]; then
        echo "OPNsense VM labs require a Linux x86_64 host with /dev/kvm." >&2
        exit 1
    fi
}

opnsense_require_base() {
    if [[ ! -f "$OPNSENSE_BASE_IMAGE" ]]; then
        cat >&2 <<EOF
Missing OPNsense base image: $OPNSENSE_BASE_IMAGE
Create it once with scripts/opnsense/prepare-base-image.sh.  See
docs/platforms/opnsense.md for the required management-interface baseline.
EOF
        exit 1
    fi
}

opnsense_stop_vm() {
    local runtime_dir="$1" name="$2"
    local pidfile="$runtime_dir/$name.pid"
    local tap

    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(<"$pidfile")"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" || true
            for _ in $(seq 1 20); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 1
            done
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" || true
        fi
        rm -f "$pidfile"
    fi

    for tap in "$runtime_dir"/*.tap; do
        [[ -e "$tap" ]] || continue
        local tap_name
        tap_name="$(<"$tap")"
        if ip link show "$tap_name" >/dev/null 2>&1; then
            ip link set "$tap_name" down || true
            ip link del "$tap_name" || true
        fi
        rm -f "$tap"
    done
}

# opnsense_start_vm <lab-dir> <name> <memory-mb> <ssh-port> <https-port>
#                    <bridge> [<bridge> ...]
# NIC order is stable: management is vtnet0, then bridge arguments are
# vtnet1..N.  The base image must have SSH enabled on its DHCP management NIC.
opnsense_start_vm() {
    local lab_dir="$1" name="$2" memory_mb="$3" ssh_port="$4" https_port="$5"
    shift 5
    local bridges=("$@")
    local runtime_dir="$lab_dir/runtime/$name"
    local overlay="$runtime_dir/overlay.qcow2"
    local pidfile="$runtime_dir/$name.pid"
    local qemu_args=() bridge tap tapfile safe_name index=1

    opnsense_require_root
    opnsense_require_host
    opnsense_require_base
    mkdir -p "$runtime_dir"
    opnsense_stop_vm "$runtime_dir" "$name"
    rm -f "$overlay"

    for bridge in "${bridges[@]}"; do
        if ! ip link show "$bridge" >/dev/null 2>&1; then
            echo "Missing bridge $bridge. Deploy the ContainerLab topology first." >&2
            exit 1
        fi
    done

    qemu-img create -q -f qcow2 -F qcow2 -b "$OPNSENSE_BASE_IMAGE" "$overlay"
    # Linux limits interface names to 15 characters.  Keep taps deterministic
    # and unique per VM without embedding the much longer bridge name.
    safe_name="${name//[^[:alnum:]]/}"
    safe_name="${safe_name:0:8}"
    for bridge in "${bridges[@]}"; do
        tap="opn-${safe_name}-${index}"
        tapfile="$runtime_dir/${index}.tap"
        ip tuntap add dev "$tap" mode tap user root
        ip link set "$tap" master "$bridge"
        ip link set "$tap" up
        printf '%s\n' "$tap" >"$tapfile"
        qemu_args+=(
            -device "virtio-net-pci,netdev=nic${index},mac=02:00:5e:$(printf '%02x' "$index"):00:01"
            -netdev "tap,id=nic${index},ifname=${tap},script=no,downscript=no"
        )
        ((index++)) || true
    done

    qemu-system-x86_64 \
        -enable-kvm -daemonize -display none -machine q35 -cpu host -smp 2 -m "$memory_mb" \
        -name "$name" -pidfile "$pidfile" \
        -serial "telnet:127.0.0.1:$((ssh_port + 2000)),server,nowait" \
        -drive "if=virtio,file=${overlay},format=qcow2" \
        -device virtio-net-pci,netdev=mgmt,mac=02:00:5e:00:00:01 \
        -netdev "user,id=mgmt,net=10.0.2.0/24,dhcpstart=10.0.2.15,hostfwd=tcp:127.0.0.1:${ssh_port}-10.0.2.15:22,hostfwd=tcp:127.0.0.1:${https_port}-10.0.2.15:443" \
        "${qemu_args[@]}"

    cat <<EOF
Started $name.
  console: telnet 127.0.0.1 $((ssh_port + 2000))
  SSH:     ssh -p $ssh_port root@127.0.0.1
  GUI:     https://127.0.0.1:$https_port
EOF
}
