#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "global-application-delivery"

P="clab-global-application-delivery"
CLIENT_A="$P-client-near-a"
OBSERVER="$P-observer"

wait_for() {
    local attempts="$1" description="$2"
    shift 2
    for _ in $(seq 1 "$attempts"); do
        "$@" && return 0
        sleep 1
    done
    echo "timeout waiting for $description" >&2
    return 1
}

dns_has() {
    local node="$CLIENT_A"
    [[ "$1" = 10.115.10.53 ]] && node="$OBSERVER"
    docker exec "$node" dig +time=1 +tries=1 +short @"$1" "$2" 2>/dev/null | grep -qx "$3"
}

stats() {
    docker exec "$P-$1-lb" sh -c \
      "printf 'show stat\\n' | socat stdio UNIX-CONNECT:/run/haproxy/admin.sock" 2>/dev/null
}

for site in site-a site-b; do
    out="$(stats "$site" || true)"
    check_contains "$site sticky pool app1 is healthy with L7 reason" "$out" 'sticky_pool,.*app1.*UP.*L7OK'
    check_contains "$site sticky pool app2 is healthy with L7 reason" "$out" 'sticky_pool,.*app2.*UP.*L7OK'
done

check_contains "near-A policy selects documentation VIP 192.0.2.10" \
    "$(docker exec "$OBSERVER" dig +time=1 +tries=1 +short @10.115.10.53 near-a.gad.test 2>/dev/null)" '^192\.0\.2\.10$'
check_contains "near-B policy selects documentation VIP 198.51.100.10" \
    "$(docker exec "$OBSERVER" dig +time=1 +tries=1 +short @10.115.10.53 near-b.gad.test 2>/dev/null)" '^198\.51\.100\.10$'

# If the Break-It fault is active, preserve it for diagnosis instead of running
# disruptive lifecycle assertions that could hide or repair the symptom.
if ! dns_has 10.115.10.53 near-a.gad.test 192.0.2.10; then
    check_contains "Break-It evidence: local pool remains green" "$(stats site-a || true)" 'health_pool,.*a-app1.*UP.*L7OK'
    check_contains "Break-It evidence: GSLB probe sees source/path denial" \
        "$(docker exec "$P-gslb" tail -20 /var/log/gad/health.log 2>/dev/null)" 'site_a=DOWN code=403'
    summary
fi

cert="$(docker exec "$CLIENT_A" sh -c \
  "printf '' | openssl s_client -connect 192.0.2.10:443 -servername shop.gad.test -CAfile /opt/gad/pki/ca.crt 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName" 2>/dev/null)"
check_contains "shop SNI selects a verified shop certificate" "$cert" 'CN ?= ?shop\.gad\.test'
check_contains "shop certificate contains the expected SAN" "$cert" 'DNS:shop\.gad\.test'

if docker exec "$CLIENT_A" curl -ksS --max-time 3 \
    --resolve wrong.gad.test:443:192.0.2.10 https://wrong.gad.test/ >/dev/null 2>&1; then
    fail "unknown SNI is rejected" "TLS request unexpectedly succeeded"
else
    pass "unknown SNI is rejected"
fi
if docker exec "$CLIENT_A" curl -sS --max-time 2 http://10.115.30.11:8080/ >/dev/null 2>&1; then
    fail "client cannot bypass the load balancer to an origin" "direct origin request succeeded"
else
    pass "client cannot bypass the load balancer to an origin"
fi

docker exec "$CLIENT_A" rm -f /tmp/gad.cookies
first="$(docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
    --resolve shop.gad.test:443:192.0.2.10 -c /tmp/gad.cookies https://shop.gad.test/)"
second="$(docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
    --resolve shop.gad.test:443:192.0.2.10 -b /tmp/gad.cookies https://shop.gad.test/)"
first_backend="$(sed -n 's/.*backend=\([^ ]*\).*/\1/p' <<<"$first")"
second_backend="$(sed -n 's/.*backend=\([^ ]*\).*/\1/p' <<<"$second")"
if [[ -n "$first_backend" && "$first_backend" = "$second_backend" ]]; then
    pass "cookie persistence retains backend $first_backend"
else
    fail "cookie persistence retains one backend" "first=$first_backend second=$second_backend"
fi

seen="$(
  for _ in $(seq 1 8); do
    docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
      --resolve shop.gad.test:443:192.0.2.10 https://shop.gad.test/stateless
  done | sed -n 's/.*backend=\([^ ]*\).*/\1/p' | sort -u | tr '\n' ' '
)"
check_contains "stateless round robin reaches both site A backends" "$seen" 'a-app1'
check_contains "stateless round robin reaches both site A backends (second)" "$seen" 'a-app2'

for backend in sticky_pool stateless_pool cache_pool api_pool health_pool; do
    docker exec "$P-site-a-lb" sh -c \
      "printf 'set server $backend/a-app1 state drain\\n' | socat stdio UNIX-CONNECT:/run/haproxy/admin.sock" >/dev/null
done
drain_seen="$(
  for _ in $(seq 1 6); do
    docker exec "$CLIENT_A" rm -f /tmp/gad.cookies
    docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
      --resolve shop.gad.test:443:192.0.2.10 -c /tmp/gad.cookies https://shop.gad.test/
  done
)"
check_not_contains "drained backend receives no new sessions" "$drain_seen" 'backend=a-app1'
for backend in sticky_pool stateless_pool cache_pool api_pool health_pool; do
    docker exec "$P-site-a-lb" sh -c \
      "printf 'set server $backend/a-app1 state ready\\n' | socat stdio UNIX-CONNECT:/run/haproxy/admin.sock" >/dev/null
done

waf_code="$(docker exec "$CLIENT_A" curl -ksS -o /dev/null -w '%{http_code}' \
    --resolve shop.gad.test:443:192.0.2.10 -H 'X-Request-ID: waf-check-001' \
    'https://shop.gad.test/?waf-test=1')"
check_contains "safe WAF seam blocks only the test signature" "$waf_code" '^403$'
normal="$(docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
    --resolve shop.gad.test:443:192.0.2.10 -H 'X-Request-ID: normal-check-001' \
    https://shop.gad.test/)"
check_contains "normal request remains allowed" "$normal" 'site=site-a'
check_contains "WAF request ID is observable in HAProxy log" \
    "$(docker exec "$P-site-a-lb" grep -F 'waf-check-001' /var/log/gad/haproxy.log 2>/dev/null)" 'waf-check-001'

docker exec "$P-edge-cache" sh -c 'rm -rf /var/cache/nginx/gad/*'
miss="$(docker exec "$CLIENT_A" curl -sS -D - -o /dev/null \
    -H 'X-Request-ID: cache-miss-001' http://10.115.20.80:8080/assets/version.txt)"
hit="$(docker exec "$CLIENT_A" curl -sS -D - -o /dev/null \
    -H 'X-Request-ID: cache-hit-001' http://10.115.20.80:8080/assets/version.txt)"
check_contains "edge cache first request is a MISS" "$miss" 'X-Cache: MISS'
check_contains "edge cache second request is a HIT" "$hit" 'X-Cache: HIT'
docker exec "$P-edge-cache" sh -c 'rm -rf /var/cache/nginx/gad/*'
purged="$(docker exec "$CLIENT_A" curl -sS -D - -o /dev/null \
    -H 'X-Request-ID: cache-purge-001' http://10.115.20.80:8080/assets/version.txt)"
check_contains "local purge makes the next request a MISS" "$purged" 'X-Cache: MISS'

# Let the five-second object freshness window expire, then make both origins
# unavailable before the next GSLB update. The edge should serve its stale copy.
sleep 6
for site in a b; do
    docker exec "$P-site-$site-lb" kill "$(docker exec "$P-site-$site-lb" cat /run/haproxy.pid)"
done
stale="$(docker exec "$CLIENT_A" curl -sS -D - -o /dev/null \
    -H 'X-Request-ID: cache-stale-001' http://10.115.20.80:8080/assets/version.txt)"
check_contains "expired cache object is served stale during origin failure" "$stale" 'X-Cache: STALE'
for site in a b; do
    docker exec "$P-site-$site-lb" sh -c '
      nohup haproxy -f /etc/haproxy/haproxy.cfg -db >>/var/log/gad/haproxy.log 2>&1 &
      echo $! >/run/haproxy.pid
    '
done
wait_for 12 "both sites after stale-cache test" dns_has 10.115.10.53 near-a.gad.test 192.0.2.10 || true
wait_for 12 "site B after stale-cache test" dns_has 10.115.10.53 near-b.gad.test 198.51.100.10 || true

# Application-layer failure: ICMP remains alive while both site A HTTP origins stop.
docker exec "$P-a-app1" nginx -s stop >/dev/null
docker exec "$P-a-app2" nginx -s stop >/dev/null
if wait_for 10 "site A authoritative withdrawal" \
    sh -c "! docker exec '$OBSERVER' dig +time=1 +tries=1 +short @10.115.10.53 near-a.gad.test | grep -qx 192.0.2.10"; then
    pass "failed application health withdraws site A"
else
    fail "failed application health withdraws site A" "192.0.2.10 remained authoritative"
fi
if docker exec "$P-gslb" ping -c1 -W1 10.115.30.11 >/dev/null 2>&1; then
    pass "ICMP remains healthy and does not mask failed application health"
else
    fail "ICMP remains healthy during application failure" "ping unexpectedly failed"
fi
docker exec "$P-a-app1" nginx
docker exec "$P-a-app2" nginx
if wait_for 12 "site A restore" dns_has 10.115.10.53 near-a.gad.test 192.0.2.10; then
    pass "site A returns after real application health recovers"
else
    fail "site A returns after real application health recovers" "authoritative answer did not restore"
fi

# Prime resolver, lose site A, and measure stale DNS versus authoritative state.
docker exec "$P-resolver" pkill dnsmasq
docker exec "$P-resolver" sh -c 'dnsmasq --conf-file=/opt/gad/dnsmasq.conf >/var/log/dnsmasq.log 2>&1 &'
sleep 1
docker exec "$CLIENT_A" dig +short @10.115.20.54 near-a.gad.test >/dev/null
start="$(date +%s)"
docker exec "$P-site-a-lb" kill "$(docker exec "$P-site-a-lb" cat /run/haproxy.pid)"
if wait_for 10 "site A loss withdrawal" \
    sh -c "! docker exec '$OBSERVER' dig +time=1 +tries=1 +short @10.115.10.53 near-a.gad.test | grep -qx 192.0.2.10"; then
    pass "site loss withdraws site A from authoritative DNS"
else
    fail "site loss withdraws site A from authoritative DNS" "site A stayed published"
fi
immediate="$(docker exec "$CLIENT_A" dig +short @10.115.20.54 near-a.gad.test)"
check_contains "resolver temporarily retains the cached site A answer" "$immediate" '^192\.0\.2\.10$'
if wait_for 12 "resolver TTL expiry" dns_has 10.115.20.54 near-a.gad.test 198.51.100.10; then
    elapsed="$(( $(date +%s) - start ))"
    if (( elapsed >= 5 && elapsed <= 12 )); then
        pass "resolver cache converges to site B in bounded time (${elapsed}s)"
    else
        fail "resolver cache converges in 5-12 seconds" "measured ${elapsed}s"
    fi
else
    fail "resolver cache converges to site B" "fallback answer not observed"
fi
fallback="$(docker exec "$CLIENT_A" curl -sS --cacert /opt/gad/pki/ca.crt \
    --resolve shop.gad.test:443:198.51.100.10 https://shop.gad.test/)"
check_contains "new client request succeeds at site B after bounded DNS behavior" "$fallback" 'site=site-b'
docker exec "$P-site-a-lb" sh -c '
  nohup haproxy -f /etc/haproxy/haproxy.cfg -db >>/var/log/gad/haproxy.log 2>&1 &
  echo $! >/run/haproxy.pid
'
wait_for 12 "site A post-loss recovery" dns_has 10.115.10.53 near-a.gad.test 192.0.2.10 || true

summary
