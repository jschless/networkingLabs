#!/usr/bin/env bash
# Restore only the live pair-protection fault, rekey, reseed, and grade.
set -Eeuo pipefail

usage() {
    printf '%s\n' 'Usage: labs/dmvpn-phase3-ipsec-capstone/repair.sh' '' \
        'Restore only the two live pair definitions, rekey/reseed, preserve all' \
        'saved hashes, and require complete checked health. Re-running is safe.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3-ipsec-capstone
lab_dir=$(cd "$(dirname "$0")" && pwd)
active_child_pid=
declare -A saved_before
stop_active_child() {
    local pid=${active_child_pid:-} attempt
    [[ -n "$pid" ]] || return 0
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill -TERM -- "-$pid" >/dev/null 2>&1 || true
        for attempt in $(seq 1 20); do kill -0 "$pid" >/dev/null 2>&1 || break; sleep 0.1; done
        kill -KILL -- "-$pid" >/dev/null 2>&1 || true
    fi
    wait "$pid" >/dev/null 2>&1 || true
    active_child_pid=
}
on_signal() { local status=$1; trap - ERR EXIT INT TERM; set +e; stop_active_child; exit "$status"; }
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'stop_active_child' EXIT
saved_sha() { docker exec "$prefix-$1" sha256sum /config/config.boot 2>/dev/null | awk '{print $1}'; }

for node in br-wan ca hub spoke1 spoke2 spoke3; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo 'ERROR: the capstone is not fully deployed' >&2; exit 1;
    }
done
for router in hub spoke1 spoke2 spoke3; do saved_before[$router]=$(saved_sha "$router"); done

deadline=$((SECONDS + 75))
restored=false
attempt=0
while (( SECONDS < deadline )); do
    ((attempt += 1))
    status2=0; timeout 25 docker exec "$prefix-spoke2" su - admin -c \
        '/bin/vbash /opt/dmvpn-capstone/restore-pair.sh' >/dev/null 2>&1 || status2=$?
    status1=0; timeout 25 docker exec "$prefix-spoke1" su - admin -c \
        '/bin/vbash /opt/dmvpn-capstone/restore-pair.sh' >/dev/null 2>&1 || status1=$?
    c1=$(docker exec "$prefix-spoke1" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
    c2=$(docker exec "$prefix-spoke2" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
    if (( status1 == 0 && status2 == 0 )) \
        && grep -q '^set vpn ipsec site-to-site peer spoke2 remote-address ' <<<"$c1" \
        && grep -q '^set vpn ipsec site-to-site peer spoke1 remote-address ' <<<"$c2"; then
        restored=true; break
    fi
    sleep 2
done
[[ "$restored" == true ]] || {
    echo "ERROR: exact minimal restore failed after $attempt bounded attempts" >&2
    exit 1
}
docker exec "$prefix-spoke1" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer spoke2 tunnel 1'\"" \
    >/dev/null 2>&1 || true

setsid --wait timeout 90 "$lab_dir/seed-shortcuts.sh" >/dev/null &
active_child_pid=$!
wait "$active_child_pid"; active_child_pid=
for router in hub spoke1 spoke2 spoke3; do
    [[ "$(saved_sha "$router")" == "${saved_before[$router]}" ]] || {
        echo 'ERROR: minimal repair changed saved learner state' >&2; exit 1;
    }
done
setsid --wait timeout 240 "$lab_dir/check.sh" &
active_child_pid=$!
wait "$active_child_pid"; active_child_pid=
echo 'Repair restored only live pair protection, preserved every saved hash, reseeded shortcuts, and passed the complete checker.'
