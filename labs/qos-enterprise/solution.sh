#!/usr/bin/env bash
# Restore the solved live state without changing the saved healthy reference.
set -euo pipefail

ROUTER="clab-qos-enterprise-router"

docker inspect "$ROUTER" >/dev/null 2>&1 || {
    echo "Repair unavailable: the lab is not running." >&2
    exit 2
}

saved_before="$(docker exec "$ROUTER" sha256sum /config/config.boot | awk '{print $1}')"
docker exec "$ROUTER" su - admin -c \
    '/bin/vbash /opt/qos/restore.sh' >/dev/null
after="$(docker exec "$ROUTER" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"")"
after="$(tr -d "'" <<<"$after")"
saved_after="$(docker exec "$ROUTER" sha256sum /config/config.boot | awk '{print $1}')"

if ! grep -qE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp EF$' \
    <<<"$after" ||
   grep -qE \
    '^set qos policy shaper WAN-QOS class 10 match VOICE ip dscp CS6$' \
    <<<"$after" ||
   [[ "$saved_before" != "$saved_after" ]]; then
    echo "Repair failed: the healthy live state was not recovered safely." >&2
    exit 1
fi

echo "Repair applied. Re-run the checker to verify the recovered policy."
