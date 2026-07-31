#!/bin/sh
set -eu

pid_file=/run/softflowd.pid
control_socket=/run/softflowd.ctl
log_file=/var/log/softflowd.log

if [ "${1:-}" = "supervise" ]; then
    trap 'rm -f "$pid_file" "$control_socket"' EXIT INT TERM
    softflowd -d -i eth1 -n 172.16.1.1:2055 -v 9 \
        -t icmp=3 -t expint=2 -t maxlife=10 \
        -c "$control_socket" &
    child_pid=$!
    printf '%s\n' "$child_pid" >"$pid_file"
    wait "$child_pid"
    exit $?
fi

ip link set eth1 up
ip link set eth1 promisc on
ip address flush dev eth1
ip link set eth2 up
ip address replace 172.16.1.2/30 dev eth2

if [ -s "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[sensor] softflowd already running"
    exit 0
fi

rm -f "$pid_file" "$control_socket"
nohup /opt/assurance/start-sensor.sh supervise >"$log_file" 2>&1 &

attempt=0
while [ "$attempt" -lt 50 ]; do
    if [ -s "$pid_file" ] && [ -S "$control_socket" ] \
        && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "[sensor] SPAN listener and NetFlow v9 exporter ready"
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

echo "[sensor] softflowd failed to become ready" >&2
tail -n 20 "$log_file" >&2 || true
exit 1
