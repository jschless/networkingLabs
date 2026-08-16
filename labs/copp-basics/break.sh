#!/usr/bin/env bash
set -euo pipefail

r1="clab-copp-basics-r1"
r2="clab-copp-basics-r2"
r3="clab-copp-basics-r3"
rollback_armed=false

restore_attachment() {
    local attempt deletion_failed input_rules first_input jump_count
    for attempt in 1 2 3; do
        : "$attempt"
        deletion_failed=false
        while docker exec "$r2" iptables -C INPUT -j COPP >/dev/null 2>&1; do
            if ! docker exec "$r2" iptables -D INPUT -j COPP >/dev/null 2>&1; then
                deletion_failed=true
                break
            fi
        done
        if "$deletion_failed" ||
           ! docker exec "$r2" iptables -I INPUT 1 -j COPP >/dev/null 2>&1; then
            sleep 0.1
            continue
        fi

        if ! input_rules="$(docker exec "$r2" iptables -S INPUT 2>/dev/null)"; then
            sleep 0.1
            continue
        fi
        first_input="$(awk '/^-A INPUT / { print; exit }' <<< "$input_rules")"
        jump_count="$(grep -c '^-A INPUT -j COPP$' <<< "$input_rules" || true)"
        if [[ "$first_input" == "-A INPUT -j COPP" && "$jump_count" == "1" ]]; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

abort() {
    local rollback_status=0
    trap - ERR INT TERM
    set +e
    if [[ "$rollback_armed" == "true" ]]; then
        restore_attachment
        rollback_status=$?
    fi
    echo "Scenario injection failed; deploy and complete the working build first." >&2
    if (( rollback_status != 0 )); then
        echo "Automatic policy-path rollback also failed; inspect r2 immediately." >&2
    fi
    exit 1
}

trap 'abort' ERR INT TERM

docker inspect "$r1" "$r2" "$r3" >/dev/null 2>&1 || abort
docker exec "$r2" test -s /etc/copp.rules.v4 >/dev/null 2>&1 || abort
docker exec "$r2" iptables -S COPP >/dev/null 2>&1 || abort
docker exec "$r2" iptables -S COPP-BGP >/dev/null 2>&1 || abort
docker exec "$r2" iptables -S COPP-OSPF >/dev/null 2>&1 || abort
docker exec "$r2" iptables -S COPP-ICMP >/dev/null 2>&1 || abort

saved_before="$(docker exec "$r2" sha256sum /etc/copp.rules.v4 | awk '{print $1}')"
rules_before="$(docker exec "$r2" iptables-save | grep -v '^#' | grep -v '^-A INPUT -j COPP$')"

rollback_armed=true
while docker exec "$r2" iptables -C INPUT -j COPP >/dev/null 2>&1; do
    docker exec "$r2" iptables -D INPUT -j COPP >/dev/null 2>&1 || abort
done

saved_after="$(docker exec "$r2" sha256sum /etc/copp.rules.v4 | awk '{print $1}')"
rules_after="$(docker exec "$r2" iptables-save | grep -v '^#' | grep -v '^-A INPUT -j COPP$')"

[[ "$saved_before" == "$saved_after" && "$rules_before" == "$rules_after" ]] || abort
! docker exec "$r2" iptables -C INPUT -j COPP >/dev/null 2>&1 || abort
bgp_state="$(docker exec "$r2" vtysh -c 'show bgp neighbor 10.1.12.1' 2>/dev/null)" || abort
ospf_state="$(docker exec "$r2" vtysh -c 'show ip ospf neighbor' 2>/dev/null)" || abort
grep -q 'BGP state = Established' <<< "$bgp_state" || abort
grep -Eq '10\.0\.0\.3[[:space:]].*Full' <<< "$ospf_state" || abort
docker exec "$r1" ping -q -c 2 -w 5 -I 10.0.0.1 10.0.0.3 >/dev/null 2>&1 || abort

rollback_armed=false
echo "Scenario injected. Begin with the observed state."
