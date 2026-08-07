#!/usr/bin/env bash
# Apply the deterministic learner fault while keeping the saved configuration.
set -euo pipefail

ROUTER="clab-qos-enterprise-router"
rollback_armed=false
rolling_back=false
saved_before=""

rollback() {
    local status="${1:-1}" restored="" saved_after=""
    trap - ERR INT TERM
    set +e

    if [[ "$rollback_armed" == true && "$rolling_back" == false ]]; then
        rolling_back=true
        docker exec "$ROUTER" su - admin -c \
            '/bin/vbash /opt/qos/restore.sh' >/dev/null 2>&1
        restored="$(docker exec "$ROUTER" bash -lc \
            "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" \
            2>/dev/null | tr -d "'")"
        saved_after="$(docker exec "$ROUTER" sha256sum /config/config.boot \
            2>/dev/null | awk '{print $1}')"

        if grep -qE \
            '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp EF$' \
            <<<"$restored" &&
           ! grep -qE \
            '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp CS6$' \
            <<<"$restored" &&
           [[ -n "$saved_before" && "$saved_after" == "$saved_before" ]]; then
            echo "Fault injection failed safely; the active policy was restored." >&2
        else
            echo "Fault injection failed; automatic recovery could not be verified." >&2
        fi
    else
        echo "Fault injection failed before the scenario was applied." >&2
    fi
    exit "$status"
}

# All prechecks are read-only. Repeated invocation accepts either the healthy
# or already-injected matcher, but no unrelated starting state.
docker inspect "$ROUTER" >/dev/null 2>&1 || {
    echo "Fault injection unavailable: the lab is not running." >&2
    exit 2
}
saved_before="$(docker exec "$ROUTER" sha256sum /config/config.boot | awk '{print $1}')"
before="$(docker exec "$ROUTER" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"")"
before="$(tr -d "'" <<<"$before")"
stable_before="$(grep -vE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp ' <<<"$before")"
ef_before="$(grep -cE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp EF$' \
    <<<"$before" || true)"
cs6_before="$(grep -cE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp CS6$' \
    <<<"$before" || true)"
if (( ef_before + cs6_before != 1 )); then
    echo "Fault injection unavailable: the current policy is not eligible." >&2
    exit 2
fi

# From this point, every error or termination signal restores and verifies the
# exact healthy live matcher before the script exits.
rollback_armed=true
trap 'rollback $?' ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

docker exec "$ROUTER" su - admin -c \
    '/bin/vbash /opt/qos/inject-fault.sh' >/dev/null

after="$(docker exec "$ROUTER" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"")"
after="$(tr -d "'" <<<"$after")"
stable_after="$(grep -vE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp ' <<<"$after")"
saved_after="$(docker exec "$ROUTER" sha256sum /config/config.boot | awk '{print $1}')"

verify_broken_state() {
    grep -qE \
        '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp CS6$' \
        <<<"$after" || return 1
    if grep -qE \
        '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp EF$' \
        <<<"$after"; then
        return 1
    fi
    [[ "$stable_before" == "$stable_after" ]] || return 1
    [[ "$saved_before" == "$saved_after" ]] || return 1
}
verify_broken_state

rollback_armed=false
trap - ERR INT TERM
echo "Fault injected. Diagnose the policy from configuration, kernel, and traffic evidence."
