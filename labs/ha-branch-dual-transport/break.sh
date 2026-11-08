#!/usr/bin/env bash
# Arm the Task 9 fault. Deliberately silent about WHAT it changes.
# Undo with: labs/ha-branch-dual-transport/repair.sh
set -Eeuo pipefail
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/ha-branch-dual-transport/lab-lib.sh
source "$lab_dir/lab-lib.sh"
hb_require_lab

if ! hb_sh host1 'ping -c 3 -W 1 10.20.20.100' >/dev/null 2>&1 \
    || ! hb_eos br1 'show vrrp brief' | grep -qE 'Po1 .* Master'; then
    echo 'ERROR: start from the healthy end state (br1 VRRP Master, host1 reaches server).' >&2
    echo '       Finish Task 8 or run solution.sh first.' >&2
    exit 1
fi

for n in acc1 acc2; do
    hb_eos_config "$n" <<'CFG'
vlan 20
   name STAGING
interface Port-Channel12
   switchport access vlan 20
CFG
done

cat <<'MSG'
Fault armed.

  TICKET #4471 — "Branch HA test failed"
  The quarterly DR test powered off br1. Users lost ALL connectivity for the
  whole test window. Nobody touched br2 recently; its BGP sessions and tunnel
  were "green" the entire time. Before the test, everything worked.

Reproduce with:  labs/ha-branch-dual-transport/measure.sh br1-off
MSG
