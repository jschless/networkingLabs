#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "network-automation-netbox"

PREFIX="clab-${TOPO_NAME}"
AUTOMATION="$PREFIX-automation"
WORKSPACE=/workspace
CHECK_DIR="$WORKSPACE/.check-$$"
EXPECTED_BUILD=6f39e5bb-e6c7-4637-b931-ecb30d43e034
CANDIDATE_HASH_BEFORE=""

auto() {
  docker exec "$AUTOMATION" "$@"
}

auto_stdin() {
  docker exec -i "$AUTOMATION" "$@"
}

candidate_hash() {
  local directory="$REPO_ROOT/labs/network-automation-netbox/automation/generated"
  if [[ ! -d "$directory" ]]; then
    printf 'missing'
    return
  fi
  (
    cd "$directory" || exit 1
    sha256sum ./*.cfg 2>/dev/null | sha256sum | awk '{print $1}'
  )
}

cleanup() {
  docker exec "$AUTOMATION" rm -rf "$CHECK_DIR" >/dev/null 2>&1 || true
  rm -f \
    "$REPO_ROOT/.network-automation-audit-$$.tsv" \
    "$REPO_ROOT/.network-automation-render-$$.log" \
    "$REPO_ROOT/.network-automation-facts-$$.log" \
    "$REPO_ROOT/.network-automation-drift-$$.log" \
    "$REPO_ROOT/.network-automation-checkmode-$$.log"
}
trap cleanup EXIT INT TERM

for service in spine1 spine2 leaf1 leaf2 postgres redis netbox automation; do
  running=$(docker inspect --format '{{.State.Running}}' \
    "$PREFIX-$service" 2>/dev/null)
  [[ "$running" == "true" ]] \
    && pass "$service container runs" \
    || fail "$service container runs" \
      "container missing or not running (State.Running=${running:-unavailable})"
done

for service in spine1 spine2 leaf1 leaf2; do
  image=$(docker inspect --format '{{.Config.Image}}' "$PREFIX-$service" 2>/dev/null)
  [[ "$image" == "ceos:4.35.2F" ]] \
    && pass "$service uses exact cEOS tag" \
    || fail "$service uses exact cEOS tag" "observed $image"
  version=$(eos "$service" "show version")
  if grep -q '4\.35\.2F-46221466\.4352F' <<<"$version" \
      && grep -q "$EXPECTED_BUILD" <<<"$version"; then
    pass "$service reports exact EOS engineering build identity"
  else
    fail "$service reports exact EOS engineering build identity" \
      "version or build ID differs"
  fi
done

declare -A SERVICE_IMAGES=(
  [netbox]='netboxcommunity/netbox:v4.1.11@sha256:d1260201d775b3f1d0b19e425bd19facc1e907e7153a8247d04d996037969e53'
  [postgres]='postgres:15@sha256:f30e3de0ac9cc938dac627ef2231099867c694b5f949fadb924c8c977428c399'
  [redis]='redis:7-alpine@sha256:8b81dd37ff027bec4e516d41acfbe9fe2460070dc6d4a4570a2ac5b9d59df065'
)
for service in netbox postgres redis; do
  image=$(docker inspect --format '{{.Config.Image}}' "$PREFIX-$service" 2>/dev/null)
  [[ "$image" == "${SERVICE_IMAGES[$service]}" ]] \
    && pass "$service uses the digest-pinned service image" \
    || fail "$service uses the digest-pinned service image" "observed $image"
done

if auto python3 "$WORKSPACE/wait_for_netbox.py" --timeout 360 >/dev/null 2>&1; then
  pass "authenticated NetBox API is ready at version 4.1.11"
else
  fail "authenticated NetBox API is ready at version 4.1.11" \
    "bounded authenticated readiness failed"
fi
docker exec "$PREFIX-postgres" pg_isready -U netbox -d netbox >/dev/null 2>&1 \
  && pass "Postgres reports ready" \
  || fail "Postgres reports ready" "pg_isready failed"
[[ "$(docker exec "$PREFIX-redis" redis-cli ping 2>/dev/null)" == "PONG" ]] \
  && pass "Redis reports ready" \
  || fail "Redis reports ready" "PING did not return PONG"

dependency_versions=$(auto python3 -c \
  'import jinja2,pynetbox,requests,yaml; print(jinja2.__version__,pynetbox.__version__,requests.__version__,yaml.__version__)' \
  2>/dev/null)
[[ "$dependency_versions" == "3.1.6 7.6.1 2.32.5 6.0.3" ]] \
  && pass "controller direct Python dependencies are exact" \
  || fail "controller direct Python dependencies are exact" "$dependency_versions"
collection_versions=$(auto ansible-galaxy collection list 2>/dev/null)
if grep -qE '^arista\.eos[[:space:]]+12\.0\.1[[:space:]]*$' <<<"$collection_versions" \
    && grep -qE '^ansible\.netcommon[[:space:]]+8\.4\.0[[:space:]]*$' <<<"$collection_versions"; then
  pass "bundled Ansible collections are exact and need no network install"
else
  fail "bundled Ansible collections are exact and need no network install" \
    "expected arista.eos 12.0.1 and ansible.netcommon 8.4.0"
fi

for service in spine1 spine2 leaf1 leaf2; do
  summary_json=$(eos "$service" 'show ip bgp summary | json')
  if python3 -c '
import json,sys
data=json.load(sys.stdin)
peers=data["vrfs"]["default"]["peers"]
raise SystemExit(0 if len(peers)==2 and all(p.get("peerState")=="Established" for p in peers.values()) else 1)
' <<<"$summary_json"; then
    pass "$service has exactly two established eBGP peers"
  else
    fail "$service has exactly two established eBGP peers" "BGP JSON did not match"
  fi
done

declare -A LOOPBACKS=(
  [spine1]=10.255.0.11
  [spine2]=10.255.0.12
  [leaf1]=10.255.0.13
  [leaf2]=10.255.0.14
)
for source in spine1 spine2 leaf1 leaf2; do
  for destination in spine1 spine2 leaf1 leaf2; do
    [[ "$source" == "$destination" ]] && continue
    check_ping_eos "$source reaches $destination loopback" \
      "$source" "${LOOPBACKS[$destination]}"
  done
done

for service in spine1 spine2 leaf1 leaf2; do
  if auto_stdin python3 - "$service" "${LOOPBACKS[$service]}" <<'PY' >/dev/null 2>&1
import sys
import requests

name = sys.argv[1]
address = {
    "spine1": "172.31.40.11",
    "spine2": "172.31.40.12",
    "leaf1": "172.31.40.13",
    "leaf2": "172.31.40.14",
}[name]
payload = {
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {"version": 1, "cmds": ["show hostname"], "format": "json"},
    "id": "read-only-check",
}
response = requests.post(
    f"http://{address}/command-api",
    auth=("admin", "admin"),
    json=payload,
    timeout=5,
)
response.raise_for_status()
assert response.json()["result"][0]["hostname"] == name
PY
  then
    pass "$service eAPI returns its native hostname"
  else
    fail "$service eAPI returns its native hostname" "authenticated HTTP probe failed"
  fi
done

auto mkdir -p "$CHECK_DIR"
if ! auto python3 "$WORKSPACE/audit_netbox.py" --phase complete \
    >"$REPO_ROOT/.network-automation-audit-$$.tsv" 2>/dev/null; then
  fail "read-only NetBox audit completed" "audit process failed"
fi
while IFS=$'\t' read -r result _key label detail; do
  if [[ "$result" == "PASS" ]]; then
    pass "$label"
  else
    fail "$label" "${detail:-audit assertion failed}"
  fi
done <"$REPO_ROOT/.network-automation-audit-$$.tsv"
rm -f "$REPO_ROOT/.network-automation-audit-$$.tsv"

CANDIDATE_HASH_BEFORE=$(candidate_hash)
if [[ "$CANDIDATE_HASH_BEFORE" != "missing" ]] \
    && [[ $(find "$REPO_ROOT/labs/network-automation-netbox/automation/generated" \
      -maxdepth 1 -type f -name '*.cfg' | wc -l) -eq 4 ]]; then
  pass "known-good generated candidate set contains exactly four files"
else
  fail "known-good generated candidate set contains exactly four files" \
    "candidate set missing or incomplete"
fi

if [[ "$CANDIDATE_HASH_BEFORE" != "missing" ]] \
    && ! grep -R -E 'username |secret |password |management api http-commands' \
      "$REPO_ROOT/labs/network-automation-netbox/automation/generated" >/dev/null 2>&1 \
    && grep -q 'vrf instance BLUE' \
      "$REPO_ROOT/labs/network-automation-netbox/automation/generated/leaf1.cfg" \
    && grep -q 'neighbor 10\.0\.0\.1 remote-as 65111' \
      "$REPO_ROOT/labs/network-automation-netbox/automation/generated/spine1.cfg"; then
  pass "candidates are secret-free native merge inputs with fabric and service intent"
else
  fail "candidates are secret-free native merge inputs with fabric and service intent" \
    "secret, bootstrap API config, or required native intent mismatch"
fi

if auto python3 "$WORKSPACE/render_from_netbox.py" \
    --output "$CHECK_DIR/render-one" >"$REPO_ROOT/.network-automation-render-$$.log" 2>&1; then
  pass "temporary native render passes complete model integrity"
  auto python3 "$WORKSPACE/render_from_netbox.py" \
    --output "$CHECK_DIR/render-two" >/dev/null 2>&1
  render_one=$(auto sh -c \
    "cd '$CHECK_DIR/render-one' && sha256sum ./*.cfg | sha256sum | awk '{print \$1}'")
  render_two=$(auto sh -c \
    "cd '$CHECK_DIR/render-two' && sha256sum ./*.cfg | sha256sum | awk '{print \$1}'")
  generated=$(candidate_hash)
  [[ "$render_one" == "$render_two" && "$render_one" == "$generated" ]] \
    && pass "native render is deterministic and matches the complete candidate set" \
    || fail "native render is deterministic and matches the complete candidate set" \
      "candidate hashes differ"
else
  fail "temporary native render passes complete model integrity" \
    "$(tail -n 1 "$REPO_ROOT/.network-automation-render-$$.log")"
  pass "failed temporary render cannot replace known-good candidates"
fi
rm -f "$REPO_ROOT/.network-automation-render-$$.log"

auto mkdir -p "$CHECK_DIR/facts"
if auto ansible-playbook -i "$WORKSPACE/inventory.yml" "$WORKSPACE/facts.yml" \
    -e "facts_output_dir=$CHECK_DIR/facts" >"$REPO_ROOT/.network-automation-facts-$$.log" 2>&1; then
  pass "fresh EOS facts were gathered from all four devices"
else
  fail "fresh EOS facts were gathered from all four devices" \
    "$(tail -n 1 "$REPO_ROOT/.network-automation-facts-$$.log")"
fi
rm -f "$REPO_ROOT/.network-automation-facts-$$.log"

if auto python3 "$WORKSPACE/drift_report.py" \
    --facts-dir "$CHECK_DIR/facts" >"$REPO_ROOT/.network-automation-drift-$$.log" 2>&1; then
  pass "ownership-aware intended versus observed drift report is clean"
else
  fail "ownership-aware intended versus observed drift report is clean" \
    "$(tail -n 1 "$REPO_ROOT/.network-automation-drift-$$.log")"
fi
rm -f "$REPO_ROOT/.network-automation-drift-$$.log"

if auto ansible-playbook -i "$WORKSPACE/inventory.yml" "$WORKSPACE/deploy.yml" \
    --check --diff >"$REPO_ROOT/.network-automation-checkmode-$$.log" 2>&1 \
    && [[ $(grep -c 'changed=0' "$REPO_ROOT/.network-automation-checkmode-$$.log") -eq 4 ]]; then
  pass "Ansible candidate/live precheck reports zero changes on all four devices"
else
  fail "Ansible candidate/live precheck reports zero changes on all four devices" \
    "check mode failed or did not report four changed=0 recaps"
fi
rm -f "$REPO_ROOT/.network-automation-checkmode-$$.log"

CANDIDATE_HASH_AFTER=$(candidate_hash)
[[ "$CANDIDATE_HASH_BEFORE" == "$CANDIDATE_HASH_AFTER" ]] \
  && pass "checker leaves generated candidates byte-for-byte untouched" \
  || fail "checker leaves generated candidates byte-for-byte untouched" \
    "candidate tree hash changed"

cleanup
if ! auto test -e "$CHECK_DIR"; then
  pass "checker removes all temporary render and facts artifacts"
else
  fail "checker removes all temporary render and facts artifacts" \
    "$CHECK_DIR remains"
fi

summary
