#!/usr/bin/env bash
# Inject one failure, measure the user-visible outage, and always restore.
#
#   labs/ha-branch-dual-transport/measure.sh --list
#   labs/ha-branch-dual-transport/measure.sh <scenario> [--fail N] [--recover N]
#
# A 20 pps ping (host1 -> server, 50 ms interval) runs for the whole trial.
# Every lost reply is 50 ms of outage. Loss is split into the FAILOVER window
# (failure injected -> repaired) and the FAILBACK window (after repair), and the
# forward/return paths are traced in the middle of the failure.
set -Eeuo pipefail

lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/ha-branch-dual-transport/lab-lib.sh
source "$lab_dir/lab-lib.sh"

INTERVAL_MS=50
PRE=3
FAIL=45      # longer than the 30 s BGP hold time, so hold-timer expiry is visible
RECOVER=35   # long enough for BGP re-establishment and VRRP preemption

declare -A DESC=(
    [host-leg]='host1 eth1 down (one LACP member toward acc1)'
    [acc1-off]='acc1 loses power (every acc1 port goes down)'
    [br1-lanleg]='br1 Ethernet2 down (one Po1 member toward acc1)'
    [crosslink]='br1<->br2 cross-link down'
    [mpls-cut]='MPLS circuit loses carrier at br1 (Ethernet1 down)'
    [mpls-silent]='MPLS circuit stays up/up but the carrier drops every packet'
    [inet-silent]='Internet circuit stays up/up but drops every packet'
    [br1-off]='br1 loses power (every br1 port goes down)'
    [br1-hang]='br1 freezes: links stay up, nothing answers (process hang)'
    [mpls-silent+crosslink]='double failure: MPLS blackholes AND the cross-link is down'
)
ORDER=(host-leg acc1-off br1-lanleg crosslink mpls-cut mpls-silent inet-silent br1-off br1-hang mpls-silent+crosslink)

usage() {
    echo "Usage: $0 --list | <scenario> [--fail SECONDS] [--recover SECONDS]"
}

list() {
    local s
    printf '%-24s %s\n' SCENARIO 'WHAT FAILS'
    for s in "${ORDER[@]}"; do printf '%-24s %s\n' "$s" "${DESC[$s]}"; done
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }
case $1 in
    -h|--help) usage; echo; list; exit 0 ;;
    --list) list; exit 0 ;;
esac
SCENARIO=$1
shift
[[ -n "${DESC[$SCENARIO]+x}" ]] || { echo "Unknown scenario: $SCENARIO" >&2; list >&2; exit 2; }
while [[ $# -gt 0 ]]; do
    case $1 in
        --fail) FAIL=$2; shift 2 ;;
        --recover) RECOVER=$2; shift 2 ;;
        *) usage >&2; exit 2 ;;
    esac
done
[[ "$FAIL" =~ ^[0-9]+$ && "$RECOVER" =~ ^[0-9]+$ && "$FAIL" -ge 6 ]] \
    || { echo 'ERROR: --fail must be >= 6 and both values whole seconds' >&2; exit 2; }

hb_require_lab

TAG=hb-measure
eos_ports() {   # eos_ports <node> <shutdown|no shutdown> <iface-range>
    printf 'interface %s\n   %s\n' "$3" "$2" | hb_eos_config "$1"
}
blackhole() {   # blackhole <node> <iface> <add|del>
    local op=-I; [[ $3 == add ]] || op=-D
    hb_sh "$1" "iptables $op INPUT -i $2 -m comment --comment $TAG -j DROP \
        && iptables $op OUTPUT -o $2 -m comment --comment $TAG -j DROP \
        && iptables $op FORWARD -i $2 -m comment --comment $TAG -j DROP \
        && iptables $op FORWARD -o $2 -m comment --comment $TAG -j DROP"
}
clear_blackholes() {
    local n
    for n in mpls inet; do
        hb_sh "$n" "for c in INPUT OUTPUT FORWARD; do
            while iptables -S \$c | grep -q -- '--comment $TAG'; do
                rule=\$(iptables -S \$c | grep -- '--comment $TAG' | head -1 | sed 's/^-A/-D/')
                eval iptables \$rule
            done; done" || true
    done
}

inject() {
    case $SCENARIO in
        host-leg)    hb_sh host1 'ip link set eth1 down' ;;
        acc1-off)    eos_ports acc1 shutdown 'Ethernet1-5' ;;
        br1-lanleg)  eos_ports br1 shutdown Ethernet2 ;;
        crosslink)   eos_ports br1 shutdown Ethernet4 ;;
        mpls-cut)    eos_ports br1 shutdown Ethernet1 ;;
        mpls-silent) blackhole mpls eth1 add ;;
        inet-silent) blackhole inet eth1 add ;;
        br1-off)     eos_ports br1 shutdown 'Ethernet1-4' ;;
        br1-hang)    docker pause "$(hb_container br1)" >/dev/null ;;
        mpls-silent+crosslink) eos_ports br1 shutdown Ethernet4; blackhole mpls eth1 add ;;
    esac
}

restore() {
    case $SCENARIO in
        host-leg)    hb_sh host1 'ip link set eth1 up' ;;
        acc1-off)    eos_ports acc1 'no shutdown' 'Ethernet1-5' ;;
        br1-lanleg)  eos_ports br1 'no shutdown' Ethernet2 ;;
        crosslink)   eos_ports br1 'no shutdown' Ethernet4 ;;
        mpls-cut)    eos_ports br1 'no shutdown' Ethernet1 ;;
        mpls-silent|inet-silent) clear_blackholes ;;
        br1-off)     eos_ports br1 'no shutdown' 'Ethernet1-4' ;;
        br1-hang)    docker unpause "$(hb_container br1)" >/dev/null ;;
        mpls-silent+crosslink) clear_blackholes; eos_ports br1 'no shutdown' Ethernet4 ;;
    esac
}

injected=false
ping_pid=''
out=$(mktemp)
cleanup() {
    local rc=$?
    trap - EXIT INT TERM
    if [[ $injected == true ]]; then
        echo '>>> restoring after interruption' >&2
        restore || echo 'WARNING: automatic restore failed; repair by hand' >&2
    fi
    [[ -z $ping_pid ]] || kill "$ping_pid" 2>/dev/null || true
    rm -f "$out"
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Refuse to start from a broken baseline: the numbers would be meaningless.
if ! hb_sh host1 'ping -c 3 -W 1 10.20.20.100' >/dev/null 2>&1; then
    echo 'ERROR: host1 cannot reach server before the trial; fix the baseline first.' >&2
    exit 1
fi

total=$((PRE + FAIL + RECOVER))
echo "=== $SCENARIO: ${DESC[$SCENARIO]}"
echo "    ${PRE}s baseline, ${FAIL}s failed, ${RECOVER}s after repair; 1 probe / ${INTERVAL_MS} ms"

docker exec "$(hb_container host1)" \
    ping -i 0.05 -W 1 -w "$total" 10.20.20.100 >"$out" 2>&1 &
ping_pid=$!

start=$(date +%s.%N)
sleep "$PRE"
t_inject=$(date +%s.%N)
injected=true
inject
echo "    [$(printf '%5.1f' "$(echo "$t_inject - $start" | bc)") s] failure injected"

sleep $((FAIL - 5))
echo '    path during failure (host1 -> server):'
hb_sh host1 'traceroute -n -q 1 -w 1 -m 6 10.20.20.100' 2>/dev/null | sed -n '2,$p' | sed 's/^/      /' || true
echo '    path during failure (server -> host1):'
hb_sh server 'traceroute -n -q 1 -w 1 -m 6 10.10.10.100' 2>/dev/null | sed -n '2,$p' | sed 's/^/      /' || true
sleep_left=$(echo "$t_inject + $FAIL - $(date +%s.%N)" | bc)
[[ $sleep_left == -* ]] || sleep "$sleep_left"

t_restore=$(date +%s.%N)
restore
injected=false
echo "    [$(printf '%5.1f' "$(echo "$t_restore - $start" | bc)") s] failure repaired"

wait "$ping_pid" || true
ping_pid=''

# busybox ping: "64 bytes from ...: seq=N ttl=.. time=.." ; seq 0 is sent at t=start
awk -v iv="$INTERVAL_MS" -v ti="$(echo "($t_inject - $start)*1000" | bc)" \
    -v tr="$(echo "($t_restore - $start)*1000" | bc)" -v total="$total" '
    /seq=/ {
        match($0, /seq=[0-9]+/); s = substr($0, RSTART + 4, RLENGTH - 4) + 0
        if ($0 ~ /DUP/) dup++; else got[s] = 1
        if (s > max) max = s
    }
    END {
        last = int(total * 1000 / iv) - 21   # ignore the -W 1 tail at the deadline
        if (max > last) last = max
        fo = fb = 0; run = 0; longest = 0
        for (s = 0; s <= last; s++) {
            if (!(s in got)) {
                t = s * iv
                if (t >= ti && t < tr) fo++; else if (t >= tr) fb++; else pre++
                run++; if (run > longest) longest = run
            } else run = 0
        }
        printf "    RESULT failover-loss: %d ms   failback-loss: %d ms   longest-gap: %d ms", fo*iv, fb*iv, longest*iv
        if (pre) printf "   baseline-loss: %d ms", pre*iv
        if (dup) printf "   duplicates: %d", dup
        printf "\n"
    }' "$out"
