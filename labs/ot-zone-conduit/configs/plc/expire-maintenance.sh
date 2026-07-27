#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$$" >/run/ot/expiry.pid
trap 'rm -f /run/ot/expiry.pid' EXIT
sleep "$DURATION"
rm -f /run/ot/maintenance.enabled
handle="$(nft -a list chain inet plc_guard input | awk '/OT-RULE-450/{print $NF}')"
[[ -z "$handle" ]] || nft delete rule inet plc_guard input handle "$handle"
