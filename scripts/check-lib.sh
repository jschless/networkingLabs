#!/usr/bin/env bash
# Shared test library for containerlab check scripts.
# Sourced by each labs/<name>/check.sh.
#
# Usage in check.sh:
#   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
#   source "$REPO_ROOT/scripts/check-lib.sh"
#   lab_init "my-lab-name"
#   ... test functions ...
#   summary

PASS=0; FAIL=0; FAIL_NAMES=()

lab_init() {
  LAB="$1"
  local topo="$REPO_ROOT/labs/$LAB/topology.clab.yml"
  [[ -f "$topo" ]] || topo="$REPO_ROOT/labs/$LAB/topology.yml"
  TOPO_NAME="$(awk '/^name:[[:space:]]*/{ print $2; exit }' "$topo")"
  echo "=== Checking lab: $LAB (topology: $TOPO_NAME) ==="
  if ! docker ps --format '{{.Names}}' | grep -q "^clab-${TOPO_NAME}-"; then
    echo "ERROR: No running containers found for lab $LAB. Deploy it first."
    exit 2
  fi
}

# --- Node exec helpers ---
eos()  { docker exec "clab-${TOPO_NAME}-$1" Cli -p 15 -c "enable" -c "$2" 2>/dev/null; }
frr()  { docker exec "clab-${TOPO_NAME}-$1" vtysh -c "$2" 2>/dev/null; }
srl()  { docker exec "clab-${TOPO_NAME}-$1" sr_cli -c "$2" 2>/dev/null; }
node() { docker exec "clab-${TOPO_NAME}-$1" bash -c "$2" 2>/dev/null; }
vyos_op() {
  docker exec "clab-${TOPO_NAME}-$1" su - admin -c \
    "/bin/vbash -ic '$2'" 2>/dev/null
}
vyos_frr() { docker exec "clab-${TOPO_NAME}-$1" vtysh -c "$2" 2>/dev/null; }

# --- Assertions ---
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; (( PASS++ )) || true; }
fail() { printf '  \033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; (( FAIL++ )) || true; FAIL_NAMES+=("$1"); }

check_contains() {
  # check_contains <test-name> <output> <regex>
  if echo "$2" | grep -qE "$3"; then pass "$1"
  else fail "$1" "expected /$3/ in output"; fi
}

check_not_contains() {
  # check_not_contains <test-name> <output> <regex>
  if ! echo "$2" | grep -qE "$3"; then pass "$1"
  else fail "$1" "unexpected /$3/ found in output"; fi
}

check_ping_eos() {
  # check_ping_eos <test-name> <node> <dest> [<source-ip>]
  local cmd="ping $3 repeat 3 timeout 2"
  [[ -n "${4:-}" ]] && cmd="ping $3 source $4 repeat 3 timeout 2"
  local out; out=$(eos "$2" "$cmd")
  if echo "$out" | grep -qE '0% packet loss|bytes from'; then pass "$1"
  else fail "$1" "ping $3 failed from $2"; fi
}

check_ping_eos_vrf() {
  # check_ping_eos_vrf <test-name> <node> <vrf> <dest> [<source-ip>]
  local cmd="ping vrf $3 $4 repeat 3 timeout 2"
  [[ -n "${5:-}" ]] && cmd="ping vrf $3 $4 source $5 repeat 3 timeout 2"
  local out; out=$(eos "$2" "$cmd")
  if echo "$out" | grep -qE '0% packet loss|bytes from'; then pass "$1"
  else fail "$1" "ping $4 via vrf $3 failed from $2"; fi
}

check_ping_linux() {
  # check_ping_linux <test-name> <node> <dest> [<source-ip>]
  local src_arg=""
  [[ -n "${4:-}" ]] && src_arg="-I $4"
  if docker exec "clab-${TOPO_NAME}-$2" ping -c3 -W2 $src_arg "$3" &>/dev/null
  then pass "$1"; else fail "$1" "ping $3 failed from $2"; fi
}

check_ping_vyos() {
  # check_ping_vyos <test-name> <node> <dest> [<source-ip>]
  local cmd="ping $3 count 3"
  [[ -n "${4:-}" ]] && cmd="ping $3 source-address $4 count 3"
  local out; out=$(vyos_op "$2" "$cmd")
  if echo "$out" | grep -qE '0% packet loss|bytes from'; then pass "$1"
  else fail "$1" "ping $3 failed from $2"; fi
}

check_no_ping_vyos() {
  # check_no_ping_vyos <test-name> <node> <dest> [<source-ip>]
  local cmd="ping $3 count 3"
  [[ -n "${4:-}" ]] && cmd="ping $3 source-address $4 count 3"
  local out; out=$(vyos_op "$2" "$cmd")
  if echo "$out" | grep -qE '100% packet loss|Network is unreachable|Name or service not known'; then pass "$1"
  else fail "$1" "ping $3 unexpectedly succeeded from $2"; fi
}

check_no_ping_linux() {
  # check_no_ping_linux <test-name> <node> <dest>
  if ! docker exec "clab-${TOPO_NAME}-$2" ping -c2 -W2 "$3" &>/dev/null
  then pass "$1"; else fail "$1" "ping $3 unexpectedly succeeded from $2"; fi
}

check_no_ping_eos() {
  # check_no_ping_eos <test-name> <node> <dest>
  local out; out=$(eos "$2" "ping $3 repeat 3 timeout 2")
  if echo "$out" | grep -qE '100% packet loss|Network is unreachable'; then pass "$1"
  else fail "$1" "ping $3 unexpectedly succeeded from $2"; fi
}

summary() {
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  if [[ $FAIL -gt 0 ]]; then
    echo "Failed tests:"
    for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
    exit 1
  fi
  exit 0
}
