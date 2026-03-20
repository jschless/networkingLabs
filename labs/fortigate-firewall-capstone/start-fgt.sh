#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root so QEMU can create tap interfaces and bind management ports." >&2
    exit 1
fi

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$LAB_DIR/runtime"
BASE_QCOW2="$RUNTIME_DIR/fortios-v4.7.11.qcow2"
OVERLAY_QCOW2="$RUNTIME_DIR/fortios-v4.7.11-overlay.qcow2"
LOG_QCOW2="$RUNTIME_DIR/fortios-logs.qcow2"
PIDFILE="$RUNTIME_DIR/fgt1.pid"
UUIDFILE="$RUNTIME_DIR/fgt1.uuid"
MONITOR_PORT="${FGT_MONITOR_PORT:-4000}"
SERIAL_PORT="${FGT_SERIAL_PORT:-5000}"

declare -A BRIDGES=(
    [wan]="br-fgt-wan"
    [corp]="br-fgt-corp"
    [guest]="br-fgt-guest"
    [dmz]="br-fgt-dmz"
    [db]="br-fgt-db"
)

declare -A TAPS=(
    [wan]="fgt1-wan"
    [corp]="fgt1-corp"
    [guest]="fgt1-guest"
    [dmz]="fgt1-dmz"
    [db]="fgt1-db"
)

mkdir -p "$RUNTIME_DIR"

if [[ ! -f "$BASE_QCOW2" ]]; then
    echo "Missing $BASE_QCOW2. Run $LAB_DIR/extract-fortios.sh first." >&2
    exit 1
fi

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "FortiGate VM already running with PID $(cat "$PIDFILE")" >&2
    exit 1
fi

for bridge in "${BRIDGES[@]}"; do
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        echo "Missing bridge $bridge. Deploy the lab first with ./scripts/lab.sh deploy fortigate-firewall-capstone" >&2
        exit 1
    fi
done

for tap in "${TAPS[@]}"; do
    if ip link show "$tap" >/dev/null 2>&1; then
        ip link set "$tap" down || true
        ip link del "$tap" || true
    fi
done

for segment in wan corp guest dmz db; do
    tap="${TAPS[$segment]}"
    bridge="${BRIDGES[$segment]}"
    ip tuntap add dev "$tap" mode tap user root
    ip link set "$tap" master "$bridge"
    ip link set "$tap" up
done

if [[ ! -f "$OVERLAY_QCOW2" ]]; then
    qemu-img create -f qcow2 -F qcow2 -b "$BASE_QCOW2" "$OVERLAY_QCOW2" >/dev/null
fi

if [[ ! -f "$LOG_QCOW2" ]]; then
    qemu-img create -f qcow2 "$LOG_QCOW2" 30G >/dev/null
fi

if [[ ! -f "$UUIDFILE" ]]; then
    cat /proc/sys/kernel/random/uuid > "$UUIDFILE"
fi

uuid_value="$(cat "$UUIDFILE")"

exec qemu-system-x86_64 \
    -enable-kvm \
    -daemonize \
    -name fortigate-firewall-capstone-fgt1 \
    -pidfile "$PIDFILE" \
    -display none \
    -machine pc \
    -monitor "tcp:127.0.0.1:${MONITOR_PORT},server,nowait" \
    -serial "telnet:127.0.0.1:${SERIAL_PORT},server,nowait" \
    -m 2048 \
    -cpu host \
    -smp 2 \
    -uuid "$uuid_value" \
    -drive "if=virtio,file=${OVERLAY_QCOW2}" \
    -drive "if=virtio,format=qcow2,file=${LOG_QCOW2},index=1" \
    -device virtio-net-pci,netdev=mgmt,mac=0C:00:FD:74:11:00 \
    -netdev user,id=mgmt,net=10.0.0.0/24,host=10.0.0.2,dns=10.0.0.3,dhcpstart=10.0.0.15,hostfwd=tcp:127.0.0.1:2222-10.0.0.15:22,hostfwd=tcp:127.0.0.1:8080-10.0.0.15:80,hostfwd=tcp:127.0.0.1:8443-10.0.0.15:443 \
    -device virtio-net-pci,netdev=wan,mac=0C:00:FD:74:11:01 \
    -netdev tap,id=wan,ifname="${TAPS[wan]}",script=no,downscript=no \
    -device virtio-net-pci,netdev=corp,mac=0C:00:FD:74:11:02 \
    -netdev tap,id=corp,ifname="${TAPS[corp]}",script=no,downscript=no \
    -device virtio-net-pci,netdev=guest,mac=0C:00:FD:74:11:03 \
    -netdev tap,id=guest,ifname="${TAPS[guest]}",script=no,downscript=no \
    -device virtio-net-pci,netdev=dmz,mac=0C:00:FD:74:11:04 \
    -netdev tap,id=dmz,ifname="${TAPS[dmz]}",script=no,downscript=no \
    -device virtio-net-pci,netdev=db,mac=0C:00:FD:74:11:05 \
    -netdev tap,id=db,ifname="${TAPS[db]}",script=no,downscript=no

echo "FortiGate VM started."
echo "  Serial console: telnet 127.0.0.1 ${SERIAL_PORT}"
echo "  SSH:            ssh -p 2222 admin@127.0.0.1"
echo "  Web UI:         http://127.0.0.1:8080 or https://127.0.0.1:8443"
