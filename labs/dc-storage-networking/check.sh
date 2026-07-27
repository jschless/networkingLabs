#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB_DIR="$REPO_ROOT/labs/dc-storage-networking"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dc-storage-networking"
P="clab-${TOPO_NAME}"
IQN="iqn.2026-07.lab.example:dc-storage"

vm() {
  docker exec "$P-initiator1" vm-exec "$@"
}

wait_two_paths() {
  for _ in $(seq 1 20); do
    vm sudo multipath -r >/dev/null 2>&1 || true
    if [[ "$(vm sudo multipath -ll 2>/dev/null | grep -c 'active ready running' || true)" -eq 2 ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if [[ "${1:-}" == "--break-it" ]]; then
  if vm ping -c2 -W1 10.111.10.20 >/dev/null; then
    pass "Break-It leaves small Storage A probes healthy"
  else
    fail "Break-It leaves small Storage A probes healthy" "small ping failed"
  fi
  if ! vm ping -M 'do' -s 8972 -c1 -W2 10.111.10.20 >/dev/null; then
    pass "Break-It drops the exact jumbo payload on Storage A"
  else
    fail "Break-It drops the exact jumbo payload on Storage A" "8972-byte payload passed"
  fi
  SESSIONS="$(vm sudo iscsiadm -m session 2>/dev/null | grep -c "$IQN" || true)"
  [[ "$SESSIONS" -eq 2 ]] \
    && pass "Break-It leaves both iSCSI sessions logged in" \
    || fail "Break-It leaves both iSCSI sessions logged in" "observed $SESSIONS sessions"
  if node tor1 'ip -o link show eth2' | grep -q 'mtu 1500'; then
    pass "Break-It root cause is the intermediate Storage A MTU"
  else
    fail "Break-It root cause is the intermediate Storage A MTU" "tor1 eth2 is not MTU 1500"
  fi
  PATH_A="$(vm sudo iscsiadm -m session -P 3 2>/dev/null | awk '
    /Current Portal: 10.111.10.20:3260/{a=1}
    a && /Attached scsi disk/{print $4; exit}')"
  PID_FILE="/run/dc-storage-break-io.pid"
  if [[ -n "$PATH_A" ]]; then
    vm sudo bash -c \
      "'dd if=/dev/$PATH_A of=/dev/null bs=1M count=8 iflag=direct status=none \
      >/tmp/dc-storage-break-io.log 2>&1 & echo \$! >$PID_FILE'"
    sleep 5
  fi
  if [[ -n "$PATH_A" ]] \
      && vm sudo bash -c "'kill -0 \$(cat $PID_FILE) 2>/dev/null'"; then
    pass "Break-It stalls direct large I/O on Storage A"
  else
    fail "Break-It stalls direct large I/O on Storage A" "bounded direct read did not remain blocked"
  fi
  # Abort only the disposable test I/O, then restore the session while leaving
  # the MTU fault in place for diagnosis and repair.
  vm sudo iscsiadm -m node -T "$IQN" -p 10.111.10.20:3260 --logout \
    >/dev/null 2>&1 || true
  vm sudo iscsiadm -m node -T "$IQN" -p 10.111.10.20:3260 --login \
    >/dev/null 2>&1 || true
  vm sudo rm -f "$PID_FILE"
  vm sudo multipath -r >/dev/null 2>&1 || true
  summary
fi

for service in tor1 tor2 initiator1 target1 target2 observer traffic-gen; do
  docker inspect "$P-$service" >/dev/null 2>&1 \
    && pass "$service container runs" \
    || fail "$service container runs" "container missing"
done

check_contains "Storage A bridge contains four isolated ports" \
  "$(node tor1 'bridge link')" 'eth4.*master br-storage-a'
check_contains "Storage B bridge contains three isolated ports" \
  "$(node tor2 'bridge link')" 'eth3.*master br-storage-b'
check_contains "management uses its own bridge" \
  "$(node observer 'bridge link')" 'eth3.*master br-mgmt'
check_not_contains "management interfaces are absent from Storage A" \
  "$(node tor1 'bridge link')" 'br-mgmt'

check_contains "target exposes only the lab file-backed LUN" \
  "$(node target1 'targetcli /backstores/fileio ls')" \
  'storage-lun.*\[/var/lib/storage/lun\.img'
check_contains "target ACL is least-privilege initiator scoped" \
  "$(node target1 "targetcli /iscsi/$IQN/tpg1/acls ls")" \
  'iqn\.2026-07\.lab\.example:initiator1'
check_not_contains "target has no loop or host block backing" \
  "$(node target1 'targetcli /backstores/fileio ls')" \
  '/dev/(loop|sd|nvme|vd)'

SESSIONS="$(vm sudo iscsiadm -m session 2>/dev/null | grep -c "$IQN" || true)"
[[ "$SESSIONS" -eq 2 ]] \
  && pass "two authenticated iSCSI sessions are established" \
  || fail "two authenticated iSCSI sessions are established" "observed $SESSIONS sessions"
MULTIPATH="$(vm sudo multipath -ll 2>/dev/null)"
check_contains "multipath map is the LIO storage LUN" "$MULTIPATH" 'LIO-ORG,storage-lun'
[[ "$(grep -c 'active ready running' <<<"$MULTIPATH" || true)" -eq 2 ]] \
  && pass "multipath has two active ready paths" \
  || fail "multipath has two active ready paths" "expected two active ready paths"
check_contains "multipath LUN is writable" "$MULTIPATH" 'wp=rw'
check_contains "guest sees only two iSCSI data disks" \
  "$(vm sudo lsblk -S -o VENDOR,MODEL,TRAN)" \
  'LIO-ORG.*storage-lun.*iscsi'

if "$LAB_DIR/integrity.sh" >/tmp/dc-storage-integrity.log 2>&1; then
  pass "bounded raw write/read checksum integrity passes"
else
  fail "bounded raw write/read checksum integrity passes" "payload and readback differed"
fi

for spec in "A 10.111.10.20 storagea" "B 10.111.20.20 storageb"; do
  read -r label address iface <<<"$spec"
  if vm ping -I "$iface" -M 'do' -s 8972 -c2 -W2 "$address" >/dev/null; then
    pass "Storage $label exact 8972-byte payload passes"
  else
    fail "Storage $label exact 8972-byte payload passes" "jumbo ping failed"
  fi
done

if ! node traffic-gen 'ping -c2 -W1 10.111.30.20' >/dev/null; then
  pass "background source cannot enter management"
else
  fail "background source cannot enter management" "management ping unexpectedly passed"
fi
if ! vm ping -I storagea -c2 -W1 10.111.30.20 >/dev/null; then
  pass "storage-data source cannot enter management"
else
  fail "storage-data source cannot enter management" "source-bound management ping passed"
fi
if node observer 'ping -c2 -W1 10.111.30.21' >/dev/null; then
  pass "management observer reaches the standby endpoint"
else
  fail "management observer reaches the standby endpoint" "management ping failed"
fi

for path in "tor1 eth1 A" "tor2 eth1 B"; do
  read -r tor iface label <<<"$path"
  node "$tor" "ip link set $iface down"
  sleep 2
  if timeout 25 "$LAB_DIR/integrity.sh" >/tmp/dc-storage-path-"$label".log 2>&1; then
    pass "I/O remains intact when Storage $label fails"
  else
    fail "I/O remains intact when Storage $label fails" "bounded integrity failed"
  fi
  node "$tor" "ip link set $iface up"
  if wait_two_paths; then
    pass "Storage $label restores without stale state"
  else
    fail "Storage $label restores without stale state" "two paths did not recover"
  fi
done

SCSI_COUNT="$(vm sudo lsblk -S -n -o VENDOR,MODEL,TRAN | grep -c 'LIO-ORG.*storage-lun.*iscsi' || true)"
[[ "$SCSI_COUNT" -eq 2 ]] \
  && pass "restore leaves no duplicate SCSI devices" \
  || fail "restore leaves no duplicate SCSI devices" "observed $SCSI_COUNT iSCSI disks"

CONTENTION="$("$LAB_DIR/contention.sh" 2>&1)"
STORAGE_MS="$(sed -n 's/^storage_ms=\([0-9]*\).*/\1/p' <<<"$CONTENTION")"
if [[ "$STORAGE_MS" =~ ^[0-9]+$ ]] && (( STORAGE_MS < 10000 )); then
  pass "validated scheduler keeps bounded storage read below 10 seconds"
else
  fail "validated scheduler keeps bounded storage read below 10 seconds" "storage_ms=${STORAGE_MS:-missing}"
fi
check_contains "storage priority class carries traffic" "$CONTENTION" \
  'class htb 1:10.*|Sent [1-9][0-9]* bytes'

summary
