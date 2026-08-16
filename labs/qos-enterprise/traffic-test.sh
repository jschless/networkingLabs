#!/usr/bin/env bash
# Run one bounded, concurrent EF/AF41/BE offer and summarize receiver results.
set -euo pipefail

TOPO_NAME="qos-enterprise"
PREFIX="clab-${TOPO_NAME}-"
DURATION=8
MACHINE=false

if [[ "${1:-}" == "--machine" ]]; then
    MACHINE=true
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--machine]" >&2
    exit 2
fi

required=(client-voice client-video client-data server)
for node in "${required[@]}"; do
    if ! docker inspect "${PREFIX}${node}" >/dev/null 2>&1; then
        echo "Traffic test unavailable: the complete lab is not running." >&2
        exit 2
    fi
done

ready=false
for _ in {1..10}; do
    listeners="$(docker exec "${PREFIX}server" ss -lnt 2>/dev/null || true)"
    if grep -qE ':5201[[:space:]]' <<<"$listeners" &&
       grep -qE ':5202[[:space:]]' <<<"$listeners" &&
       grep -qE ':5203[[:space:]]' <<<"$listeners"; then
        ready=true
        break
    fi
    sleep 1
done
if [[ "$ready" != true ]]; then
    echo "Traffic test unavailable: the three receivers are not ready." >&2
    exit 2
fi

stop_stale_clients() {
    local node="$1"
    docker exec "${PREFIX}${node}" sh -c '
        for comm in /proc/[0-9]*/comm; do
            [ -r "$comm" ] || continue
            [ "$(cat "$comm")" = "iperf3" ] || continue
            pid=${comm#/proc/}; pid=${pid%/comm}
            kill "$pid" 2>/dev/null || true
        done
    ' >/dev/null
}

for node in client-voice client-video client-data; do
    stop_stale_clients "$node"
done

result_dir="$(mktemp -d)"
pids=()
cleanup() {
    local pid
    for pid in "${pids[@]:-}"; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    for node in client-voice client-video client-data; do
        stop_stale_clients "$node" 2>/dev/null || true
    done
    rm -rf -- "$result_dir"
}
trap cleanup EXIT

run_offer() {
    local node="$1" port="$2" rate="$3" tos="$4" output="$5"
    timeout "$((DURATION + 8))" docker exec "${PREFIX}${node}" \
        iperf3 -c 10.2.0.2 -p "$port" -u -b "$rate" -t "$DURATION" \
        -S "$tos" -l 1200 --connect-timeout 3000 -J >"$output" 2>&1 &
    pids+=("$!")
}

run_offer client-voice 5201 500k 0xb8 "$result_dir/voice.json"
run_offer client-video 5202 1m 0x88 "$result_dir/video.json"
run_offer client-data 5203 4m 0x00 "$result_dir/data.json"

failed=false
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        failed=true
    fi
done
pids=()
if [[ "$failed" == true ]]; then
    echo "Traffic test failed before all three bounded offers completed." >&2
    exit 1
fi

python3 - "$MACHINE" \
    "$result_dir/voice.json" "$result_dir/video.json" "$result_dir/data.json" <<'PY'
import json
import sys

machine = sys.argv[1] == "true"
names = ("voice", "video", "data")
offered = {"voice": 500_000.0, "video": 1_000_000.0, "data": 4_000_000.0}
results = {}

for name, path in zip(names, sys.argv[2:]):
    with open(path, encoding="utf-8") as stream:
        payload = json.load(stream)
    if "error" in payload:
        raise SystemExit(f"{name} offer failed: {payload['error']}")
    end = payload.get("end", {})
    summary = end.get("sum_received") or end.get("sum")
    if not isinstance(summary, dict) or "lost_percent" not in summary:
        streams = end.get("streams", [])
        summary = streams[0].get("udp", {}) if streams else {}
    try:
        loss = float(summary["lost_percent"])
        received = float(summary["bits_per_second"])
    except (KeyError, TypeError, ValueError) as exc:
        raise SystemExit(f"{name} result was not parseable") from exc
    results[name] = (loss, received)

aggregate = sum(value[1] for value in results.values())
if machine:
    for name in names:
        loss, received = results[name]
        print(f"{name}_offered_bps={offered[name]:.0f}")
        print(f"{name}_received_bps={received:.0f}")
        print(f"{name}_loss_pct={loss:.3f}")
    print(f"aggregate_received_bps={aggregate:.0f}")
else:
    print("Class   DSCP   Offered     Received    Loss")
    for name, dscp in zip(names, ("EF", "AF41", "BE")):
        loss, received = results[name]
        print(
            f"{name:<7} {dscp:<5} {offered[name] / 1_000_000:>5.1f} Mbit/s  "
            f"{received / 1_000_000:>5.2f} Mbit/s  {loss:>6.2f}%"
        )
    print(f"Aggregate receiver throughput: {aggregate / 1_000_000:.2f} Mbit/s")
PY
