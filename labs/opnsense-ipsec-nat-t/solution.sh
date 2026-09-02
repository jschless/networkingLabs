#!/usr/bin/env bash
# Transactionally replace the lab-owned OPNsense saved/live state and grade it.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/opnsense-ipsec-nat-t/solution.sh' \
        '' \
        'Replace the two disposable firewalls data-plane and IPsec lab state,' \
        'converge native OPNsense 26.1 services, and run the exact checker.'
}
case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$lab_dir/lab-lib.sh"

hq_backup=
branch_backup=
rollback_armed=false
hold_pid=

make_backup() {
    local port=$1 backup
    backup=$(natt_sh "$port" <<'EOF'
umask 077
backup_dir=$(mktemp -d /tmp/natt-solution.XXXXXX) || exit 1
cp -p /conf/config.xml "$backup_dir/config.xml" || exit 1
printf '%s\n' "$backup_dir"
EOF
)
    [[ "$backup" =~ ^/tmp/natt-solution\.[[:alnum:]]{6}$ ]] || {
        echo "ERROR: firewall backup path was not safely bounded" >&2
        return 1
    }
    printf '%s\n' "$backup"
}

delete_backup() {
    local port=$1 backup=$2
    [[ -z "$backup" ]] && return 0
    natt_sh "$port" "$backup" <<'EOF' >/dev/null
backup=$1
rm -f "$backup/config.xml" && rmdir "$backup"
EOF
}

restore_backup() {
    local port=$1 backup=$2
    [[ -z "$backup" ]] && return 0
    natt_sh "$port" "$backup" <<'EOF' >/dev/null
backup=$1
test -f "$backup/config.xml" &&
    cp -p "$backup/config.xml" /conf/config.xml &&
    rm -f "$backup/config.xml" &&
    rmdir "$backup"
EOF
    natt_reload_restored "$port"
}

rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
        hold_pid=
    fi
    if [[ "$rollback_armed" == true ]]; then
        restore_backup "$NATT_HQ_PORT" "$hq_backup" || rollback_status=1
        restore_backup "$NATT_BRANCH_PORT" "$branch_backup" || rollback_status=1
    fi
    (( rollback_status == 0 )) \
        || echo "ERROR: saved/live rollback failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

natt_require_tools
natt_require_containers
natt_ssh_ready "$NATT_HQ_PORT" \
    || { echo "ERROR: HQ OPNsense SSH is not ready" >&2; exit 1; }
natt_ssh_ready "$NATT_BRANCH_PORT" \
    || { echo "ERROR: Branch OPNsense SSH is not ready" >&2; exit 1; }

hq_backup=$(make_backup "$NATT_HQ_PORT")
rollback_armed=true
branch_backup=$(make_backup "$NATT_BRANCH_PORT")

natt_php "$NATT_HQ_PORT" hq base "$lab_dir/configure.php" >/dev/null
natt_php "$NATT_BRANCH_PORT" branch base "$lab_dir/configure.php" >/dev/null

hold=${NATT_SOLUTION_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo "ERROR: test hold must be an integer" >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi
[[ ${NATT_SOLUTION_TEST_FAIL_AFTER_BASE:-0} != 1 ]] || false

natt_reload_base "$NATT_HQ_PORT" >/dev/null
natt_reload_base "$NATT_BRANCH_PORT" >/dev/null

# enc0 is a dynamic saved interface. The MVC firewall rule validates only
# after native interface registration has made that interface visible.
natt_php "$NATT_HQ_PORT" hq firewall "$lab_dir/configure.php" >/dev/null
natt_php "$NATT_BRANCH_PORT" branch firewall "$lab_dir/configure.php" >/dev/null
natt_ssh "$NATT_HQ_PORT" 'configctl filter reload' >/dev/null
natt_ssh "$NATT_BRANCH_PORT" 'configctl filter reload' >/dev/null

converged=false
for _attempt in $(seq 1 45); do
    if natt_protected_ready; then
        converged=true
        break
    fi
    sleep 1
done
[[ "$converged" == true ]] \
    || { echo "ERROR: native IKEv2/NAT-T state did not converge in the bounded wait" >&2; exit 1; }

"$lab_dir/check.sh" || {
    echo "ERROR: protected traffic converged, but exact saved/live grading failed" >&2
    exit 1
}

# The exact healthy state is the transaction commit point. Never attempt a
# partial two-peer rollback after either backup has been deleted.
rollback_armed=false
trap - ERR EXIT INT TERM
cleanup_status=0
if delete_backup "$NATT_HQ_PORT" "$hq_backup"; then
    hq_backup=
else
    echo "ERROR: committed state is healthy, but HQ backup cleanup may remain at $hq_backup" >&2
    cleanup_status=1
fi
if delete_backup "$NATT_BRANCH_PORT" "$branch_backup"; then
    branch_backup=
else
    echo "ERROR: committed state is healthy, but Branch backup cleanup may remain at $branch_backup" >&2
    cleanup_status=1
fi
(( cleanup_status == 0 )) || exit 1
echo "Healthy native OPNsense IKEv2/NAT-T state applied, saved, and verified."
