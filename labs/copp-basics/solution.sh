#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")" && pwd)"
r2="clab-copp-basics-r2"

abort() {
    echo "Repair validation failed; inspect the deployed lab state." >&2
    exit 1
}

docker inspect "$r2" >/dev/null 2>&1 || abort
docker exec "$r2" test -s /etc/copp.rules.v4 >/dev/null 2>&1 || abort
docker exec "$r2" iptables -S COPP >/dev/null 2>&1 || abort
saved_before="$(docker exec "$r2" sha256sum /etc/copp.rules.v4 | awk '{print $1}')"

while docker exec "$r2" iptables -C INPUT -j COPP >/dev/null 2>&1; do
    docker exec "$r2" iptables -D INPUT -j COPP >/dev/null 2>&1 || abort
done
docker exec "$r2" iptables -I INPUT 1 -j COPP >/dev/null 2>&1 || abort

input_rules="$(docker exec "$r2" iptables -S INPUT)"
first_input="$(awk '/^-A INPUT / { print; exit }' <<< "$input_rules")"
input_jump_count="$(grep -c '^-A INPUT -j COPP$' <<< "$input_rules" || true)"
saved_after="$(docker exec "$r2" sha256sum /etc/copp.rules.v4 | awk '{print $1}')"

[[ "$first_input" == "-A INPUT -j COPP" ]] || abort
[[ "$input_jump_count" == "1" ]] || abort
[[ "$saved_before" == "$saved_after" ]] || abort
"$lab_dir/check.sh" >/dev/null || abort

echo "Repair applied and validated."
