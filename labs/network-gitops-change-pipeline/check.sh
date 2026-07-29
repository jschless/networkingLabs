#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "network-gitops-change-pipeline"

P="clab-${TOPO_NAME}"
AUTOMATION="$P-automation"
WORK="/workspace/lab-repo"
MODE="${1:-full}"

auto() {
  docker exec -w "$WORK" "$AUTOMATION" "$@"
}

wait_corp_path() {
  local _
  for _ in $(seq 1 40); do
    if docker exec "$P-client" curl -fsS --interface 10.112.10.10 \
        --max-time 3 http://10.112.20.10:8080/ 2>/dev/null \
        | grep -q 'approved-service-path'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

for service in leaf1 leaf2 edge1 client app observer automation; do
  docker inspect "$P-$service" >/dev/null 2>&1 \
    && pass "$service container runs" \
    || fail "$service container runs" "container missing"
done

if [[ "$MODE" == "--baseline" ]]; then
  COMMIT_COUNT="$(auto git rev-list --count HEAD 2>/dev/null)"
  [[ "$COMMIT_COUNT" -eq 1 ]] \
    && pass "disposable repository has one identified baseline commit" \
    || fail "disposable repository has one identified baseline commit" \
      "observed $COMMIT_COUNT commits"
  [[ -z "$(auto git status --porcelain 2>/dev/null)" ]] \
    && pass "baseline internal Git repository is clean" \
    || fail "baseline internal Git repository is clean" "working tree is dirty"
  if ! auto test -e intent/change.yml \
      && ! auto test -e templates/device.j2 \
      && ! auto test -e workflow/change-policy.yml; then
    pass "core intent, rendering, and safe workflow policy are withheld"
  else
    fail "core intent, rendering, and safe workflow policy are withheld" \
      "solution files exist in baseline repo"
  fi
  for device in leaf1 leaf2 edge1; do
    check_contains "$device starts at baseline description" \
      "$(eos "$device" 'show interfaces Loopback0 description')" \
      'gitops-baseline'
    check_not_contains "$device has no GitOps canary route at baseline" \
      "$(eos "$device" 'show ip route 203.0.113.12/32')" \
      '203\.0\.113\.12/32'
  done
  if wait_corp_path; then
    pass "baseline corp service path works"
  else
    fail "baseline corp service path works" "corp HTTP failed"
  fi
  if ! docker exec "$P-client" curl -fsS --interface 10.112.10.20 \
      --max-time 4 http://10.112.20.10:8080/ >/dev/null 2>&1; then
    pass "baseline guest-to-app path is denied"
  else
    fail "baseline guest-to-app path is denied" "guest HTTP unexpectedly worked"
  fi
  summary
fi

if auto pytest -q >/tmp/network-gitops-pytest.log 2>&1; then
  pass "intent schema, referential integrity, and repository-boundary tests pass"
else
  fail "intent schema, referential integrity, and repository-boundary tests pass" \
    "$(tail -n 1 /tmp/network-gitops-pytest.log)"
fi

HASH_ONE="$(auto python3 -m pipeline.cli render 2>/dev/null \
  | sha256sum | awk '{print $1}')"
HASH_TWO="$(auto python3 -m pipeline.cli render 2>/dev/null \
  | sha256sum | awk '{print $1}')"
[[ "$HASH_ONE" == "$HASH_TWO" ]] \
  && pass "rendering is deterministic and stable ordered" \
  || fail "rendering is deterministic and stable ordered" \
    "$HASH_ONE differs from $HASH_TWO"

if auto python3 -m pipeline.cli plan >/tmp/network-gitops-change-plan.json 2>&1 \
    && jq -e \
      '.workflow.transaction.rollback == "configure-replace" and
       .workflow.transaction.commit == "staged-stop-on-first-error" and
       .workflow.reconciliation.drift == "explicit-adopt-or-revert"' \
      /tmp/network-gitops-change-plan.json >/dev/null; then
  pass "student-owned workflow requires safe transaction and reconciliation"
else
  fail "student-owned workflow requires safe transaction and reconciliation" \
    "safe workflow policy or review artifact missing"
fi

if ! auto python3 -m pipeline.cli run --intent intent/bad-route-leak.yml \
    >/tmp/network-gitops-bad-route.log 2>&1; then
  pass "pre-check rejects unauthorized default/prefix change"
else
  fail "pre-check rejects unauthorized default/prefix change" \
    "unsafe route intent passed"
fi
if ! auto python3 -m pipeline.cli run --intent intent/bad-management.yml \
    >/tmp/network-gitops-bad-mgmt.log 2>&1; then
  pass "management reachability is protected from candidates"
else
  fail "management reachability is protected from candidates" \
    "management candidate passed"
fi
if auto sh -c \
    "jq -e 'select(.status == \"rejected_precheck\" and .device_access_count == 0)' evidence/*/summary.json >/dev/null"; then
  pass "rejected pre-check performs zero device API calls"
else
  fail "rejected pre-check performs zero device API calls" \
    "missing zero-access evidence"
fi

for device in leaf1 leaf2 edge1; do
  check_contains "$device has declared v2 structured state" \
    "$(eos "$device" 'show interfaces Loopback0 description')" 'gitops-v2'
  check_contains "$device has approved canary route" \
    "$(eos "$device" 'show ip route 203.0.113.12/32')" \
    '203\.0\.113\.12/32'
done

if wait_corp_path; then
  pass "corp service path works after change"
else
  fail "corp service path works after change" "corp HTTP failed"
fi
if ! docker exec "$P-client" curl -fsS --interface 10.112.10.20 \
    --max-time 4 http://10.112.20.10:8080/ >/dev/null 2>&1; then
  pass "guest deny remains enforced after change"
else
  fail "guest deny remains enforced after change" "guest HTTP unexpectedly worked"
fi

if auto python3 -m pipeline.cli verify >/dev/null 2>&1; then
  if auto python3 -m pipeline.cli run >/tmp/network-gitops-idempotent.log 2>&1 \
      && auto sh -c \
        "jq -e 'select(.status == \"success\" and .idempotent == true and (.changed | length) == 0)' evidence/*/summary.json >/dev/null"; then
    pass "second pipeline run is idempotent with zero device changes"
  else
    fail "second pipeline run is idempotent with zero device changes" \
      "idempotent evidence missing"
  fi
else
  fail "second pipeline run is idempotent with zero device changes" \
    "fleet is not at declared intent; refusing another deploy"
fi

if [[ "$MODE" == "--success" ]]; then
  summary
fi

if auto sh -c \
    "jq -e 'select(.status == \"partial_rolled_back\" and .failed_device == \"leaf2\" and .applied == [\"leaf1\"] and .rollback == [\"leaf1\"] and (.stopped_before | index(\"edge1\")))' evidence/*/summary.json >/dev/null"; then
  pass "partial push was detected and explicitly rolled back"
else
  fail "partial push was detected and explicitly rolled back" \
    "partial_rolled_back evidence missing"
fi

if auto python3 -m pipeline.cli inject-drift --device leaf1 >/dev/null \
    && ! auto python3 -m pipeline.cli drift >/tmp/network-gitops-drift.log 2>&1 \
    && grep -q 'emergency-manual-change' /tmp/network-gitops-drift.log; then
  pass "manual drift is detected with a semantic diff"
else
  fail "manual drift is detected with a semantic diff" \
    "drift command did not expose emergency change"
fi

if auto python3 -m pipeline.cli reconcile --mode adopt --device leaf1 >/dev/null \
    && auto grep -q 'emergency-manual-change' intent/adopted.yml; then
  pass "adopt path creates reviewable intent without changing device state"
else
  fail "adopt path creates reviewable intent without changing device state" \
    "adopted intent missing"
fi

if auto python3 -m pipeline.cli reconcile --mode revert --device leaf1 >/dev/null \
    && auto python3 -m pipeline.cli drift >/dev/null 2>&1; then
  pass "revert path reconciles drift idempotently"
else
  fail "revert path reconciles drift idempotently" "drift remains"
fi
auto rm -f intent/adopted.yml

auto python3 -m pipeline.cli make-postcheck-fixture >/dev/null
if ! auto python3 -m pipeline.cli run \
    --intent intent/postcheck-failure.yml >/tmp/network-gitops-postfail.log 2>&1 \
    && auto sh -c \
      "jq -e 'select(.status == \"failed_rolled_back\" and (.applied | length) == 3 and (.rollback | length) == 3)' evidence/*/summary.json >/dev/null" \
    && auto python3 -m pipeline.cli verify >/dev/null 2>&1; then
  pass "failed post-check restores device and service invariants"
else
  fail "failed post-check restores device and service invariants" \
    "rollback evidence or restored v2 state missing"
fi
auto rm -f intent/postcheck-failure.yml

if ! docker exec -w /tmp -e PYTHONPATH="$WORK" "$AUTOMATION" \
    python3 -m pipeline.cli survey >/tmp/network-gitops-boundary.log 2>&1; then
  pass "pipeline refuses to operate outside the disposable internal repository"
else
  fail "pipeline refuses to operate outside the disposable internal repository" \
    "boundary check unexpectedly passed"
fi

if ! auto grep -R -E 'admin|EAPI_PASSWORD|Authorization|Basic [A-Za-z0-9+/=]+' \
    evidence >/tmp/network-gitops-secret-scan.log 2>&1; then
  pass "failed and successful evidence contain no secret values"
else
  fail "failed and successful evidence contain no secret values" \
    "secret-like value found in evidence"
fi

if auto sh -c \
    "find evidence -name 'candidate-*.cfg' -o -name semantic-diff.json -o -name postcheck.json | grep -q ."; then
  pass "attempts preserve candidates, semantic diffs, and post-check evidence"
else
  fail "attempts preserve candidates, semantic diffs, and post-check evidence" \
    "required artifact missing"
fi

summary
