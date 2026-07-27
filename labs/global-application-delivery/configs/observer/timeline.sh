#!/bin/sh
set -eu
resolver="${1:-10.115.20.54}"
name="${2:-near-a.gad.test}"
request_id="${3:-timeline-001}"
printf 'time=%s phase=resolver-query name=%s\n' "$(date -u +%H:%M:%S)" "$name"
dig +noall +answer "@$resolver" "$name"
target="$(dig +short "@$resolver" "$name" | head -1)"
printf 'time=%s phase=tcp-tls target=%s sni=shop.gad.test\n' "$(date -u +%H:%M:%S)" "$target"
curl -sS --cacert /opt/gad/pki/ca.crt --resolve "shop.gad.test:443:$target" \
    -H "X-Request-ID: $request_id" -D - https://shop.gad.test/ -o -
