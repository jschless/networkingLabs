#!/usr/bin/env bash
# End-state checks. Run after completing the practice tasks: ./scripts/lab.sh check zero-trust-secure-access
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init zero-trust-secure-access

token() {
  node "$1" "curl -fsS -X POST http://10.90.30.10:8080/realms/ztna/protocol/openid-connect/token -d grant_type=password -d client_id=pep -d client_secret=LAB-ONLY-PEP-SECRET -d username=$2 -d password=$3 | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"access_token\"])'"
}
http_code() { node "$1" "$2" | tr -d '\r\n'; }

for service in idp pep pki log-viewer public-app finance-app ops-app; do
  docker inspect "clab-${TOPO_NAME}-${service}" >/dev/null 2>&1 && pass "$service container runs" || fail "$service container runs" "container missing"
done
check_contains 'OIDC issuer is ready' "$(node managed-client 'curl -fsS http://10.90.30.10:8080/realms/ztna/.well-known/openid-configuration')" '10\.90\.30\.10.*realms/ztna'
check_contains 'PEP TLS health endpoint is ready' "$(node managed-client 'curl -fsS --cacert /runtime/ca.crt https://10.90.20.10:8443/healthz')" '"ready": true'

fin_token="$(token managed-client finuser LAB-ONLY-finance-password)"
ops_token="$(token unmanaged-client opsuser LAB-ONLY-ops-password)"
partner_token="$(token unmanaged-client partneruser LAB-ONLY-partner-password)"
managed_finance="curl -fsS --cacert /runtime/ca.crt --cert /runtime/clients/managed-client.crt --key /runtime/clients/managed-client.key -H 'Authorization: Bearer $fin_token' https://10.90.20.10:8443/finance"
if node managed-client "$managed_finance" | grep -q 'finance-app'; then pass 'managed finance user with certificate reaches finance'; else fail 'managed finance user with certificate reaches finance' 'request denied'; fi
if [ "$(http_code unmanaged-client "curl -sk -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer $fin_token' https://10.90.20.10:8443/finance")" = 403 ]; then pass 'unmanaged finance user is denied device-required resource'; else fail 'unmanaged finance user is denied device-required resource' 'expected 403'; fi
if node unmanaged-client "curl -fsS --cacert /runtime/ca.crt -H 'Authorization: Bearer $ops_token' https://10.90.20.10:8443/ops" | grep -q 'ops-app'; then pass 'operations group reaches operations'; else fail 'operations group reaches operations' 'request denied'; fi
if [ "$(http_code unmanaged-client "curl -sk -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer $ops_token' https://10.90.20.10:8443/finance")" = 403 ]; then pass 'operations group does not reach finance'; else fail 'operations group does not reach finance' 'expected 403'; fi
if node unmanaged-client "curl -fsS --cacert /runtime/ca.crt -H 'Authorization: Bearer $partner_token' https://10.90.20.10:8443/partner" | grep -q 'finance-app'; then pass 'partner reaches its single approved route'; else fail 'partner reaches its single approved route' 'request denied'; fi
if [ "$(http_code unmanaged-client "curl -sk -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer $partner_token' https://10.90.20.10:8443/ops")" = 403 ]; then pass 'partner cannot reach operations'; else fail 'partner cannot reach operations' 'expected 403'; fi
if node unmanaged-client 'curl -fsS --cacert /runtime/ca.crt https://10.90.20.10:8443/public' | grep -q 'public-app'; then pass 'anonymous client reaches public resource only'; else fail 'anonymous client reaches public resource only' 'request denied'; fi

bad_token='eyJhbGciOiJub25lIn0.eyJpc3MiOiJodHRwOi8vYmFkLWlzc3VlciIsImF1ZCI6WyJub3QtcGVwIl19.'
if [ "$(http_code managed-client "curl -sk -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer $bad_token' https://10.90.20.10:8443/ops")" = 401 ]; then pass 'wrong issuer and audience token is rejected'; else fail 'wrong issuer and audience token is rejected' 'expected 401'; fi
for target in 10.90.40.10 10.90.40.11 10.90.40.12; do
  if [ "$(http_code unmanaged-client "curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://$target:8080/")" = 000 ]; then pass "remote client cannot directly reach origin $target"; else fail "remote client cannot directly reach origin $target" 'origin bypass succeeded'; fi
done
if ! node finance-app 'ping -c1 -W1 10.90.10.11' >/dev/null; then pass 'protected origin cannot initiate to remote zone'; else fail 'protected origin cannot initiate to remote zone' 'ICMP unexpectedly passed'; fi
if ! node finance-app 'ping -c1 -W1 10.90.30.10' >/dev/null; then pass 'protected origin cannot initiate to identity zone'; else fail 'protected origin cannot initiate to identity zone' 'ICMP unexpectedly passed'; fi
check_contains 'firewall permits PEP to origin only on required port' "$(node seg-gw 'nft list ruleset')" 'iif "eth2" oif "eth4" ip saddr 10\.90\.20\.10 tcp dport 8080 accept'
check_contains 'decision log includes permit' "$(node log-viewer 'curl -fsS http://127.0.0.1:8080/')" '"decision": "permit"'
check_contains 'decision log includes deny' "$(node log-viewer 'curl -fsS http://127.0.0.1:8080/')" '"decision": "deny"'
revocation_token="$(token managed-client finuser LAB-ONLY-finance-password)"
admin='/opt/keycloak/bin/kcadm.sh'
node idp "$admin config credentials --server http://localhost:8080 --realm master --user lab-admin --password LAB-ONLY-admin-credential" >/dev/null
fin_id="$(node idp "$admin get users -r ztna -q username=finuser" | sed -n 's/.*"id" : "\([^"]*\)".*/\1/p' | head -1)"
node idp "$admin update users/$fin_id -r ztna -s enabled=false" >/dev/null
if [ "$(http_code managed-client "curl -sk -s -o /dev/null -w '%{http_code}' --cert /runtime/clients/managed-client.crt --key /runtime/clients/managed-client.key -H 'Authorization: Bearer $revocation_token' https://10.90.20.10:8443/finance")" = 401 ]; then pass 'disabled user token is rejected by introspection'; else fail 'disabled user token is rejected by introspection' 'expected 401 within one request'; fi
node idp "$admin update users/$fin_id -r ztna -s enabled=true" >/dev/null

if [ "${1:-}" = --break-it ]; then
  node seg-gw 'nft insert rule inet zt forward iif eth1 oif eth4 tcp dport 8080 accept'
  if node managed-client "$managed_finance" | grep -q finance-app && [ "$(http_code unmanaged-client "curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://10.90.40.11:8080/")" = 200 ]; then
    fail 'Break-It independent origin path assertion' 'PEP remains correct while a broad remote-to-origin rule bypasses it'
  else
    fail 'Break-It setup' 'expected proxied permit and direct bypass'
  fi
  summary
fi
summary
