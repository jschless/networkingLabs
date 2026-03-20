#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$LAB_DIR/runtime"
FORTIOS_IMAGE="${FORTIOS_IMAGE:-vrnetlab/vr-fortios:4.7.11}"
BASE_QCOW2="$RUNTIME_DIR/fortios-v4.7.11.qcow2"

mkdir -p "$RUNTIME_DIR"

if [[ -f "$BASE_QCOW2" ]]; then
    echo "FortiGate base image already extracted at $BASE_QCOW2"
    exit 0
fi

container_id="$(docker create "$FORTIOS_IMAGE")"
cleanup() {
    docker rm -f "$container_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker cp "$container_id:/fortios-v4.7.11.qcow2" "$BASE_QCOW2"

echo "Extracted FortiGate base qcow2 to $BASE_QCOW2"
