#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB_DIR="$REPO_ROOT/labs/ot-zone-conduit"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ot-zone-conduit"
P="clab-${TOPO_NAME}"

latest_ok_ts() {
  node "$1" "jq -r 'select(.ok == true) | .ts' /run/ot/$1.jsonl 2>/dev/null | tail -1"
}

age_is_at_most() {
  local node_name="$1" max_age="$2" ts now
  ts="$(latest_ok_ts "$node_name")"
  now="$(date +%s)"
  [[ "$ts" =~ ^[0-9]+$ ]] && (( now - ts <= max_age ))
}

if [[ "${1:-}" == "--break-it" ]]; then
  stale=0
  for _ in $(seq 1 15); do
    hist_ts="$(latest_ok_ts historian)"
    now="$(date +%s)"
    if [[ "$hist_ts" =~ ^[0-9]+$ ]] && (( now - hist_ts >= 6 )); then
      stale=1
      break
    fi
    sleep 1
  done
  if (( stale )); then
    pass "Break-It makes historian data stale"
  else
    fail "Break-It makes historian data stale" "last good sample did not age beyond six seconds"
  fi
  if age_is_at_most hmi 4; then
    pass "Break-It leaves HMI reads current"
  else
    fail "Break-It leaves HMI reads current" "HMI last-good sample is stale"
  fi
  check_contains "Break-It return-path rule has matching packets" \
    "$(node idmz-fw 'nft -a list chain inet ot_conduits forward')" \
    'counter packets [1-9].*OT-BREAK-900'
  summary
fi

for service in enterprise-user enterprise-rtr idmz-fw jump historian site-rtr \
  cell-switch hmi eng-ws plc1 plc2 ids attacker-test; do
  docker inspect "$P-$service" >/dev/null 2>&1 \
    && pass "$service container runs" \
    || fail "$service container runs" "container missing"
done

HMI_READ="$(node hmi '/opt/ot/modbus-client read 10.110.40.101')"
check_contains "HMI reads approved PLC1 registers" "$HMI_READ" \
  '"values": \[420, 73\]'

historian_ready=0
for _ in $(seq 1 5); do
  if age_is_at_most historian 5 \
    && node historian \
      '/opt/ot/modbus-client read 10.110.40.101 --timeout 1' >/dev/null; then
    historian_ready=1
    break
  fi
  sleep 1
done
if (( historian_ready )); then
  pass "historian receives periodic PLC data"
else
  fail "historian receives periodic PLC data" "no current successful sample"
fi

if node eng-ws '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 74' >/dev/null; then
  fail "engineering write is denied outside maintenance" "write unexpectedly succeeded"
else
  pass "engineering write is denied outside maintenance"
fi
if node attacker-test '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 99' >/dev/null; then
  fail "unauthorized write is denied" "attacker-test write unexpectedly succeeded"
else
  pass "unauthorized write is denied"
fi

"$LAB_DIR/enable-maintenance.sh" 30 >/dev/null
if node eng-ws '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 77' >/dev/null; then
  pass "authorized engineering write succeeds during maintenance"
else
  fail "authorized engineering write succeeds during maintenance" "write was denied"
fi
if node attacker-test '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 99' >/dev/null; then
  fail "maintenance window remains source-scoped" "attacker-test write succeeded"
else
  pass "maintenance window remains source-scoped"
fi
node eng-ws '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 73' >/dev/null || true
"$LAB_DIR/disable-maintenance.sh" >/dev/null
if node eng-ws '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 74' >/dev/null; then
  fail "maintenance expiry closes engineering writes" "write succeeded after disable"
else
  pass "maintenance expiry closes engineering writes"
fi
"$LAB_DIR/enable-maintenance.sh" 5 >/dev/null
expired=0
for _ in $(seq 1 9); do
  if ! node plc1 'test -e /run/ot/maintenance.enabled'; then
    expired=1
    break
  fi
  sleep 1
done
if (( expired )) && ! node eng-ws \
  '/opt/ot/modbus-client write 10.110.40.101 --address 1 --value 74' >/dev/null; then
  pass "maintenance policy expires automatically"
else
  fail "maintenance policy expires automatically" "window or write authorization remained active"
fi

JUMP_OUT="$(node enterprise-user \
  "sshpass -p LAB-ONLY-enterprise-to-jump ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 otmaint@10.110.20.10 sshpass -p LAB-ONLY-jump-to-engineering ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null maint@10.110.40.20 echo ENG_OK" || true)"
check_contains "enterprise maintenance reaches engineering only through jump" \
  "$JUMP_OUT" '^ENG_OK$'
check_contains "jump authentication is logged separately" \
  "$(node jump 'cat /run/ot/ssh-auth.log')" 'Accepted password for otmaint'
check_contains "engineering authentication is logged separately" \
  "$(node eng-ws 'cat /run/ot/ssh-auth.log')" 'Accepted password for maint'

if node enterprise-user 'nc -z -w2 10.110.40.101 502'; then
  fail "enterprise user cannot reach PLC directly" "direct Modbus connected"
else
  pass "enterprise user cannot reach PLC directly"
fi
if node jump 'nc -z -w2 10.110.40.101 502'; then
  fail "jump reaches only approved management endpoint and port" "jump reached PLC Modbus"
else
  pass "jump reaches only approved management endpoint and port"
fi
if node plc1 'ping -c1 -W1 10.110.10.10' >/dev/null; then
  fail "PLC cannot initiate into enterprise" "PLC ping unexpectedly succeeded"
else
  pass "PLC cannot initiate into enterprise"
fi

sleep 2
check_contains "IDS parses Modbus and alerts on unauthorized write" \
  "$(node ids "jq -r 'select(.event_type == \"alert\" and .app_proto == \"modbus\") | .alert.signature' /run/ot/eve.json")" \
  '^LAB-OT unauthorized engineering write attempt$'
docker pause "$P-ids" >/dev/null
if node hmi '/opt/ot/modbus-client read 10.110.40.101' >/dev/null; then
  pass "passive IDS is not a forwarding dependency"
else
  fail "passive IDS is not a forwarding dependency" "HMI read failed while IDS paused"
fi
docker unpause "$P-ids" >/dev/null

min_ts=9999999999
max_ts=0
for service in idmz-fw historian site-rtr hmi plc1 ids; do
  ts="$(node "$service" 'date +%s')"
  (( ts < min_ts )) && min_ts="$ts"
  (( ts > max_ts )) && max_ts="$ts"
done
if (( max_ts - min_ts <= 2 )); then
  pass "zone clocks are within the two-second correlation bound"
else
  fail "zone clocks are within the two-second correlation bound" "spread was $((max_ts-min_ts)) seconds"
fi

IDMZ_RULES="$(node idmz-fw 'nft list ruleset')"
SITE_RULES="$(node site-rtr 'nft list ruleset')"
check_contains "IDMZ conduit rule IDs and counters are visible" "$IDMZ_RULES" \
  'OT-RULE-210'
check_contains "site conduit rule IDs and counters are visible" "$SITE_RULES" \
  'OT-RULE-410'
check_contains "IDMZ historian conduit counter increments" \
  "$(node idmz-fw 'nft list counter inet ot_conduits historian_to_plc')" \
  'packets [1-9]'
check_contains "site historian conduit counter increments" \
  "$(node site-rtr 'nft list counter inet site_conduits idmz_historian_to_cell')" \
  'packets [1-9]'
check_contains "firewall logs carry explicit rule IDs" \
  "$(node idmz-fw 'cat /run/ot/firewall.log')" \
  'OT-RULE-(110 enterprise-jump|210 historian-plc|999 default-deny)'

check_contains "enterprise route uses the intended IDMZ firewall path" \
  "$(node enterprise-rtr 'ip route get 10.110.40.101')" \
  'via 10\.110\.11\.2 dev eth2'
check_contains "site route returns through the intended IDMZ firewall" \
  "$(node site-rtr 'ip route get 10.110.20.20')" \
  'via 10\.110\.30\.1 dev eth1'
check_not_contains "host files do not bypass zone policy" \
  "$(node enterprise-user 'cat /etc/hosts')" \
  '10\.110\.40\.(101|102)'

summary
