#!/usr/bin/env bash
# Bounded packet proof for BFD control traffic and OSPF hellos on r1-r2.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$lab_dir/lab-lib.sh"

capture_dir=$(mktemp -d /tmp/bfd-ospf-capture.XXXXXX)
[[ "$capture_dir" =~ ^/tmp/bfd-ospf-capture\.[[:alnum:]]{6}$ ]] || exit 1
chmod 700 "$capture_dir"
bfd_pid=''
ospf_pid=''
hold_pid=''
bfd_tag="bfd-ospf-bfd-${BASHPID}-${RANDOM}"
ospf_tag="bfd-ospf-ospf-${BASHPID}-${RANDOM}"

stop_tagged_capture() {
    local tag=$1
    timeout -k 2 8 docker exec -i "$(bo_container r1)" timeout -k 1 6 bash -s -- "$tag" <<'EOF' >/dev/null 2>&1 || true
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
for _attempt in $(seq 1 20); do
    [[ -n "$(find_tagged)" ]] || exit 0
    sleep 0.1
done
mapfile -t pids < <(find_tagged)
(( ${#pids[@]} == 0 )) || kill -KILL "${pids[@]}" 2>/dev/null || true
[[ -z "$(find_tagged)" ]]
EOF
}

cleanup() {
    trap - EXIT INT TERM
    [[ -z "$hold_pid" ]] || { kill "$hold_pid" 2>/dev/null || true; wait "$hold_pid" 2>/dev/null || true; }
    [[ -z "$bfd_pid" ]] || { kill "$bfd_pid" 2>/dev/null || true; wait "$bfd_pid" 2>/dev/null || true; }
    [[ -z "$ospf_pid" ]] || { kill "$ospf_pid" 2>/dev/null || true; wait "$ospf_pid" 2>/dev/null || true; }
    stop_tagged_capture "$bfd_tag"
    stop_tagged_capture "$ospf_tag"
    rm -f "$capture_dir/bfd.txt" "$capture_dir/ospf.txt"
    rmdir "$capture_dir" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

bo_require_tools
bo_require_inventory || { echo 'ERROR: exact bfd-ospf topology is not running' >&2; exit 1; }
bo_healthy_ready || { echo 'ERROR: apply and verify the exact healthy state before capturing' >&2; exit 1; }

timeout -k 2 22 docker exec "$(bo_container r1)" timeout -k 1 18 bash -c \
    'exec -a "$1" tcpdump -lnni eth1 -c 8 "udp port 3784"' bash "$bfd_tag" \
    >"$capture_dir/bfd.txt" 2>&1 &
bfd_pid=$!
timeout -k 2 30 docker exec "$(bo_container r1)" timeout -k 1 26 bash -c \
    'exec -a "$1" tcpdump -lnni eth1 -c 2 "ip proto 89"' bash "$ospf_tag" \
    >"$capture_dir/ospf.txt" 2>&1 &
ospf_pid=$!

[[ ${BFD_OSPF_CAPTURE_TEST_FAIL_AFTER_START:-0} != 1 ]] || false
hold=${BFD_OSPF_CAPTURE_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then sleep "$hold" & hold_pid=$!; wait "$hold_pid"; hold_pid=; fi

wait "$bfd_pid"; bfd_pid=
wait "$ospf_pid"; ospf_pid=

bfd_packets=$(grep -Ec '10\.1\.12\.[12]\.[0-9]+ > 10\.1\.12\.[12]\.3784: BFDv[0-9]' "$capture_dir/bfd.txt" || true)
bfd_from_r1=$(grep -Ec '10\.1\.12\.1\.[0-9]+ > 10\.1\.12\.2\.3784: BFDv[0-9]' "$capture_dir/bfd.txt" || true)
bfd_from_r2=$(grep -Ec '10\.1\.12\.2\.[0-9]+ > 10\.1\.12\.1\.3784: BFDv[0-9]' "$capture_dir/bfd.txt" || true)
ospf_packets=$(grep -Eci '10\.1\.12\.[12] > 224\.0\.0\.5: OSPFv2, Hello' "$capture_dir/ospf.txt" || true)
ospf_from_r1=$(grep -Eci '10\.1\.12\.1 > 224\.0\.0\.5: OSPFv2, Hello' "$capture_dir/ospf.txt" || true)
ospf_from_r2=$(grep -Eci '10\.1\.12\.2 > 224\.0\.0\.5: OSPFv2, Hello' "$capture_dir/ospf.txt" || true)

sed -n '1,12p' "$capture_dir/bfd.txt"
sed -n '1,8p' "$capture_dir/ospf.txt"
[[ "$bfd_packets" == 8 && "$bfd_from_r1" -gt 0 && "$bfd_from_r2" -gt 0 ]] || {
    echo 'ERROR: bounded BFD capture did not contain eight controls with both link sources' >&2
    exit 1
}
[[ "$ospf_packets" == 2 && "$ospf_from_r1" -gt 0 && "$ospf_from_r2" -gt 0 ]] || {
    echo 'ERROR: bounded OSPF capture did not contain two hellos with both link sources' >&2
    exit 1
}
echo 'PASS: bounded r1-r2 capture proves bidirectional UDP/3784 BFD controls and OSPFv2 hellos.'
