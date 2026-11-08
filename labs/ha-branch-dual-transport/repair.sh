#!/usr/bin/env bash
# Undo the Task 9 fault (restores the healthy end state's access VLANs).
set -Eeuo pipefail
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/ha-branch-dual-transport/lab-lib.sh
source "$lab_dir/lab-lib.sh"
hb_require_lab
for n in acc1 acc2; do
    hb_eos_config "$n" <<'CFG'
interface Port-Channel12
   switchport access vlan 10
no vlan 20
CFG
done
echo 'Repaired. Allow ~5 s for VRRP to settle, then: show vrrp brief on br1 and br2.'
