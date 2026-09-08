#!/usr/bin/env bash
# Prove tenant traffic uses only its dedicated inter-PE link.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/vrf-lite/lab-lib.sh
source "$lab_dir/lab-lib.sh"

capture_dir=$(mktemp -d /tmp/vrf-lite-capture.XXXXXX)
[[ "$capture_dir" =~ ^/tmp/vrf-lite-capture\.[[:alnum:]]{6}$ ]] || exit 1
chmod 700 "$capture_dir"
red_pid=
blue_pid=
hold_pid=
red_tag="vrf-lite-red-${BASHPID}-${RANDOM}"
blue_tag="vrf-lite-blue-${BASHPID}-${RANDOM}"

stop_tagged_capture() {
    local tag=$1
    docker exec -i "$(vl_container pe1)" bash -s -- "$tag" <<'EOF' >/dev/null 2>&1 || true
tag=$1
find_tagged() {
    local proc command pid
    for proc in /proc/[0-9]*/cmdline; do
        [[ -r "$proc" ]] || continue
        command=$(tr '\0' ' ' <"$proc" 2>/dev/null || true)
        [[ "$command" == "$tag "* ]] || continue
        pid=${proc#/proc/}; pid=${pid%/cmdline}
        printf '%s\n' "$pid"
    done
}
mapfile -t pids < <(find_tagged)
(( ${#pids[@]} == 0 )) || kill "${pids[@]}" 2>/dev/null || true
for _attempt in $(seq 1 30); do
    [[ -n "$(find_tagged)" ]] || exit 0
    sleep 0.1
done
mapfile -t pids < <(find_tagged)
(( ${#pids[@]} == 0 )) || kill -KILL "${pids[@]}" 2>/dev/null || true
for _attempt in $(seq 1 10); do
    [[ -n "$(find_tagged)" ]] || exit 0
    sleep 0.1
done
exit 1
EOF
}

cleanup() {
    trap - EXIT INT TERM
    [[ -z "$hold_pid" ]] || { kill "$hold_pid" 2>/dev/null || true; wait "$hold_pid" 2>/dev/null || true; }
    [[ -z "$red_pid" ]] || { kill "$red_pid" 2>/dev/null || true; wait "$red_pid" 2>/dev/null || true; }
    [[ -z "$blue_pid" ]] || { kill "$blue_pid" 2>/dev/null || true; wait "$blue_pid" 2>/dev/null || true; }
    stop_tagged_capture "$red_tag"
    stop_tagged_capture "$blue_tag"
    rm -f "$capture_dir/red.txt" "$capture_dir/blue.txt"
    rmdir "$capture_dir" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

vl_require_tools
vl_require_inventory || { echo 'ERROR: exact vrf-lite topology is not running' >&2; exit 1; }
vl_healthy_ready || { echo 'ERROR: apply and verify the healthy state before capturing' >&2; exit 1; }

timeout 15 docker exec "$(vl_container pe1)" timeout 12 bash -c \
    'exec -a "$1" tcpdump -lni eth2 -c 6 icmp' bash "$red_tag" \
    >"$capture_dir/red.txt" 2>&1 &
red_pid=$!
timeout 15 docker exec "$(vl_container pe1)" timeout 12 bash -c \
    'exec -a "$1" tcpdump -lni eth4 -c 6 icmp' bash "$blue_tag" \
    >"$capture_dir/blue.txt" 2>&1 &
blue_pid=$!
sleep 1

[[ ${VRF_LITE_CAPTURE_TEST_FAIL_AFTER_START:-0} != 1 ]] || false
hold=${VRF_LITE_CAPTURE_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

vl_node ce-a1 ping -c 3 -W 1 -I 10.10.0.1 10.10.0.2 >/dev/null
vl_node ce-b1 ping -c 3 -W 1 -I 10.20.0.1 10.20.0.2 >/dev/null
wait "$red_pid"; red_pid=
wait "$blue_pid"; blue_pid=

red_requests=$(grep -Ec '10\.10\.0\.1 > 10\.10\.0\.2: ICMP echo request' "$capture_dir/red.txt" || true)
red_replies=$(grep -Ec '10\.10\.0\.2 > 10\.10\.0\.1: ICMP echo reply' "$capture_dir/red.txt" || true)
blue_requests=$(grep -Ec '10\.20\.0\.1 > 10\.20\.0\.2: ICMP echo request' "$capture_dir/blue.txt" || true)
blue_replies=$(grep -Ec '10\.20\.0\.2 > 10\.20\.0\.1: ICMP echo reply' "$capture_dir/blue.txt" || true)

sed -n '1,8p' "$capture_dir/red.txt"
sed -n '1,8p' "$capture_dir/blue.txt"
[[ "$red_requests" == 3 && "$red_replies" == 3 \
    && "$blue_requests" == 3 && "$blue_replies" == 3 ]] || {
    echo 'ERROR: bounded captures did not contain the exact request/reply counts' >&2
    exit 1
}
! grep -q '10\.20\.0\.' "$capture_dir/red.txt" || {
    echo 'ERROR: BLUE traffic appeared on the RED inter-PE link' >&2
    exit 1
}
! grep -q '10\.10\.0\.' "$capture_dir/blue.txt" || {
    echo 'ERROR: RED traffic appeared on the BLUE inter-PE link' >&2
    exit 1
}
echo 'PASS: each bounded capture contains exactly three requests and replies only for its tenant.'
