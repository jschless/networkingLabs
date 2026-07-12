#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
attempt="$(mktemp -d)"
trap 'rm -rf "$attempt"' EXIT

"$DIR/capture.sh" "$attempt" node-a -- sh -c 'printf "node-a-ok\\n"' &
first=$!
"$DIR/capture.sh" "$attempt" node-b -- sh -c 'printf "node-b-ok\\n"' &
second=$!
wait "$first"
wait "$second"

for node in node-a node-b; do
    typescript="$(find "$attempt/sessions" -name "*-${node}.typescript" -print -quit)"
    timing="$(find "$attempt/sessions" -name "*-${node}.timing" -print -quit)"
    [[ -s "$typescript" ]] || { echo "missing output transcript for $node" >&2; exit 1; }
    [[ -s "$timing" ]] || { echo "missing timing transcript for $node" >&2; exit 1; }
    grep -q "${node}-ok" "$typescript"
done
echo "PASS: concurrent script output and timing logs were captured."
