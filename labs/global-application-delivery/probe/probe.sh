#!/usr/bin/env bash
set -euo pipefail

LAB_IMAGE="global-delivery:local"
NET="gad-feature-probe"
PREFIX="gad-probe"
WORK="$(mktemp -d)"
STARTED="$(date +%s)"

cleanup() {
    docker rm -f "${PREFIX}-client" "${PREFIX}-resolver" "${PREFIX}-gslb" \
        "${PREFIX}-site-a" "${PREFIX}-site-b" >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT
cleanup

docker build -t "$LAB_IMAGE" "$(cd "$(dirname "$0")/.." && pwd)"
docker network create --subnet 10.115.250.0/24 "$NET" >/dev/null

mkdir -p "$WORK/certs" "$WORK/gslb"
docker run --rm -v "$WORK/certs:/certs" "$LAB_IMAGE" sh -c '
openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
  -subj "/CN=GAD Probe CA" -keyout /certs/ca.key -out /certs/ca.crt >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj "/CN=shop.gad.test" \
  -keyout /certs/shop.key -out /certs/shop.csr >/dev/null 2>&1
printf "subjectAltName=DNS:shop.gad.test\n" >/certs/ext
openssl x509 -req -in /certs/shop.csr -CA /certs/ca.crt -CAkey /certs/ca.key \
  -CAcreateserial -days 7 -extfile /certs/ext -out /certs/shop.crt >/dev/null 2>&1
cat /certs/shop.crt /certs/shop.key >/certs/shop.pem
'

cat >"$WORK/site.sh" <<'EOF'
#!/bin/sh
set -eu
SITE="$1"
mkdir -p /run/nginx /var/lib/nginx/html
printf 'site=%s backend=one\n' "$SITE" >/var/lib/nginx/html/index.html
printf 'ok\n' >/var/lib/nginx/html/health
cat >/etc/nginx/http.d/default.conf <<NGINX
server { listen 8081; root /var/lib/nginx/html; add_header X-Backend ${SITE}-one; }
NGINX
nginx
cat >/etc/haproxy/haproxy.cfg <<HAPROXY
global
  log stdout format raw local0
  stats socket /run/haproxy.sock mode 660 level admin
defaults
  log global
  mode http
  timeout connect 1s
  timeout client 10s
  timeout server 10s
frontend tls
  bind :443 ssl crt /certs/shop.pem strict-sni
  http-request deny status 403 if { urlp(waf-test) -m str 1 }
  default_backend apps
backend apps
  option httpchk GET /health
  http-check expect status 200
  server one 127.0.0.1:8081 check
HAPROXY
haproxy -f /etc/haproxy/haproxy.cfg -db
EOF
chmod +x "$WORK/site.sh"

for site in a b; do
    ip="10.115.250.$([ "$site" = a ] && echo 11 || echo 12)"
    docker run -d --name "${PREFIX}-site-${site}" --network "$NET" --ip "$ip" \
        -v "$WORK/certs:/certs:ro" -v "$WORK/site.sh:/site.sh:ro" \
        "$LAB_IMAGE" sh /site.sh "$site" >/dev/null
done

cat >"$WORK/gslb/Corefile" <<'EOF'
.:53 {
  errors
  log
  hosts /gslb/hosts {
    ttl 8
    reload 1s
  }
}
EOF
cat >"$WORK/gslb/controller.sh" <<'EOF'
#!/bin/sh
set -eu
while true; do
  : >/gslb/hosts.new
  for spec in "10.115.250.11 192.0.2.10" "10.115.250.12 198.51.100.10"; do
    set -- $spec
    if curl -ksSf --connect-timeout 1 "https://shop.gad.test/health" \
       --resolve shop.gad.test:443:"$1" >/dev/null; then
      printf '%s shop.gad.test\n' "$2" >>/gslb/hosts.new
    fi
  done
  mv /gslb/hosts.new /gslb/hosts
  sleep 1
done
EOF
chmod +x "$WORK/gslb/controller.sh"
touch "$WORK/gslb/hosts"
docker run -d --name "${PREFIX}-gslb" --network "$NET" --ip 10.115.250.53 \
    -v "$WORK/gslb:/gslb" "$LAB_IMAGE" sh -c \
    'sh /gslb/controller.sh >/gslb/controller.log 2>&1 & exec coredns -conf /gslb/Corefile' >/dev/null

cat >"$WORK/dnsmasq.conf" <<'EOF'
no-resolv
no-hosts
log-queries
server=10.115.250.53
cache-size=100
min-cache-ttl=0
EOF
docker run -d --name "${PREFIX}-resolver" --network "$NET" --ip 10.115.250.54 \
    -v "$WORK/dnsmasq.conf:/etc/dnsmasq.conf:ro" "$LAB_IMAGE" \
    dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf >/dev/null
docker run -d --name "${PREFIX}-client" --network "$NET" --ip 10.115.250.20 \
    -v "$WORK/certs:/certs:ro" "$LAB_IMAGE" sleep infinity >/dev/null

for _ in $(seq 1 15); do
    answers="$(docker exec "${PREFIX}-client" dig +short @10.115.250.54 shop.gad.test | sort)"
    [ "$(printf '%s\n' "$answers" | grep -cE '^(192\.0\.2\.10|198\.51\.100\.10)$')" -eq 2 ] && break
    sleep 1
done
printf 'initial_answers=%s\n' "$(echo "$answers" | tr '\n' ',')"

docker exec "${PREFIX}-client" curl -sS --cacert /certs/ca.crt \
    --resolve shop.gad.test:443:10.115.250.11 https://shop.gad.test/ |
    grep -q 'site=a'
echo "tls_sni=PASS"

if docker exec "${PREFIX}-client" curl -ksS --resolve wrong.gad.test:443:10.115.250.11 \
    https://wrong.gad.test/ >/dev/null 2>&1; then
    echo "wrong_sni=FAIL"
    exit 1
fi
echo "wrong_sni=PASS"

code="$(docker exec "${PREFIX}-client" curl -ksS -o /dev/null -w '%{http_code}' \
    --resolve shop.gad.test:443:10.115.250.11 'https://shop.gad.test/?waf-test=1')"
[ "$code" = 403 ]
echo "safe_waf_rule=PASS"

docker restart "${PREFIX}-resolver" >/dev/null
sleep 1
docker exec "${PREFIX}-client" dig +short @10.115.250.54 shop.gad.test >/dev/null
before="$(date +%s)"
docker exec "${PREFIX}-site-a" nginx -s stop
for _ in $(seq 1 12); do
    auth="$(docker exec "${PREFIX}-client" dig +short @10.115.250.53 shop.gad.test | sort)"
    ! grep -q '^192\.0\.2\.10$' <<<"$auth" && break
    sleep 1
done
withdrawn="$(date +%s)"
printf 'authoritative_withdraw_seconds=%s answers=%s\n' \
    "$((withdrawn - before))" "$(echo "$auth" | tr '\n' ',')"
! grep -q '^192\.0\.2\.10$' <<<"$auth"

cached="$(docker exec "${PREFIX}-client" dig +short @10.115.250.54 shop.gad.test | sort)"
printf 'resolver_immediate_cached_answers=%s\n' "$(echo "$cached" | tr '\n' ',')"
grep -q '^192\.0\.2\.10$' <<<"$cached"
for _ in $(seq 1 10); do
    cached="$(docker exec "${PREFIX}-client" dig +short @10.115.250.54 shop.gad.test | sort)"
    ! grep -q '^192\.0\.2\.10$' <<<"$cached" && break
    sleep 1
done
expired="$(date +%s)"
printf 'resolver_cache_expiry_seconds=%s answers=%s\n' \
    "$((expired - before))" "$(echo "$cached" | tr '\n' ',')"
! grep -q '^192\.0\.2\.10$' <<<"$cached"

stats="$(docker exec "${PREFIX}-site-b" sh -c \
    "printf 'show stat\\n' | socat stdio UNIX-CONNECT:/run/haproxy.sock")"
grep -q 'apps,one' <<<"$stats"
docker exec "${PREFIX}-site-b" sh -c \
    "printf 'set server apps/one state drain\\n' | socat stdio UNIX-CONNECT:/run/haproxy.sock" >/dev/null
drain="$(docker exec "${PREFIX}-site-b" sh -c \
    "printf 'show servers state apps\\n' | socat stdio UNIX-CONNECT:/run/haproxy.sock")"
grep -q ' one ' <<<"$drain"
echo "runtime_drain_observable=PASS"

docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' \
    "${PREFIX}-client" "${PREFIX}-resolver" "${PREFIX}-gslb" \
    "${PREFIX}-site-a" "${PREFIX}-site-b"
printf 'elapsed_seconds=%s\n' "$(( $(date +%s) - STARTED ))"
