#!/usr/bin/env bash
# End-state controls and business-flow assertions.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init advanced-security-architecture

http_code() {
    node "$1" "$2" | tr -d '\r\n'
}

expect_code() {
    local name="$1" node_name="$2" expected="$3" command="$4" actual
    actual="$(http_code "$node_name" "$command")"
    if [[ "$actual" == "$expected" ]]; then pass "$name"
    else fail "$name" "expected HTTP $expected, got ${actual:-empty}"; fi
}

event_id="asa-check-$(date +%s)-$$"

for service in internet-test edge ngfw core user protected-app waf-pep partner security-services admin break-glass; do
    if docker inspect "clab-${TOPO_NAME}-${service}" >/dev/null 2>&1; then
        pass "$service container runs"
    else
        fail "$service container runs" "container missing"
    fi
done

check_contains "management interface is isolated in a Linux VRF" \
    "$(node ngfw 'ip -d link show MGMT')" 'vrf table 1050'
check_contains "user access segment is isolated in a core VRF" \
    "$(node core 'ip -d link show USER')" 'vrf table 1010'
check_contains "server access segment is isolated in a separate core VRF" \
    "$(node core 'ip -d link show SERVER')" 'vrf table 1020'
check_contains "stateful policy has an established-flow fast path" \
    "$(node ngfw 'nft list ruleset')" 'ct state established,related.*accept'
check_contains "public translation is exact" \
    "$(node ngfw 'nft list table ip asa_nat')" '198\.51\.100\.80.*dnat to 10\.114\.30\.10:8080'

public_body="$(node internet-test "curl -fsS --max-time 4 -H 'X-Lab-Event: $event_id' http://198.51.100.80/public-app" || true)"
check_contains "public application succeeds through publication address" "$public_body" '"role": "protected-app"'
check_contains "public response traversed the intended origin" "$public_body" '"path": "/public-app"'

hairpin_body="$(node user "curl -fsS --max-time 4 -H 'X-Lab-Event: $event_id-hairpin' http://198.51.100.80/public-app" || true)"
check_contains "internal hairpin reaches the same WAF path" "$hairpin_body" '"role": "protected-app"'
check_contains "internal user reaches approved protected application flow" \
    "$(node user 'curl -fsS --max-time 4 http://10.114.20.20:8080/internal-app' || true)" '"path": "/internal-app"'

expect_code "internet cannot bypass WAF to protected origin" internet-test 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://10.114.20.20:8080/public-app"
expect_code "partner cannot bypass PEP/WAF to protected origin" partner 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://10.114.20.20:8080/partner-app"
expect_code "internet cannot address the private WAF directly" internet-test 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://10.114.30.10:8080/public-app"

partner_token="$(node partner 'cat /run/partner.token')"
partner_body="$(node partner "curl -fsS --max-time 4 -H 'Authorization: Bearer $partner_token' -H 'X-Lab-Event: $event_id-partner' http://10.114.30.10:8443/partner-app" || true)"
check_contains "partner assertion reaches its one resource" "$partner_body" '"path": "/partner-app"'
expect_code "partner assertion cannot reach internal resource" partner 403 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 4 -H 'Authorization: Bearer $partner_token' -H 'X-Lab-Event: $event_id-partner-deny' http://10.114.30.10:8443/internal-app"

check_contains "admin reaches OOB management service" \
    "$(node admin 'curl -fsS --max-time 3 http://10.114.50.1:8443/healthz' || true)" '"role": "management"'
check_contains "dedicated break-glass source reaches OOB management service" \
    "$(node break-glass 'curl -fsS --max-time 3 http://10.114.50.1:8443/healthz' || true)" '"role": "management"'
expect_code "user zone cannot reach management service" user 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://10.114.50.1:8443/healthz"

check_contains "approved DNS answer comes from controlled resolver" \
    "$(node user 'dig +short +time=2 +tries=1 @10.114.60.10 approved.test A')" '^203\.0\.113\.80$'
check_not_contains "unapproved test domain is refused by controlled resolver" \
    "$(node user 'dig +short +time=2 +tries=1 @10.114.60.10 blocked.test A')" '[0-9]+\.[0-9]+'
expect_code "direct resolver bypass is denied" user 000 \
    "dig +time=2 +tries=1 @203.0.113.53 approved.test A >/dev/null 2>&1; test \$? -eq 0 && printf 200 || printf 000"
check_contains "approved egress succeeds through explicit proxy" \
    "$(node user 'curl -fsS --max-time 5 -x http://10.114.60.10:3128 http://approved.test:8080/approved' || true)" '"path": "/approved"'
expect_code "unapproved egress is denied by proxy policy" user 403 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 5 -x http://10.114.60.10:3128 http://blocked.test:8080/"
expect_code "direct HTTP egress bypass is denied" user 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://203.0.113.80:8080/approved"

node internet-test "curl -sS -o /dev/null --max-time 4 http://198.51.100.80/ids-alert" || true
sleep 1
check_contains "safe IDS marker generated an alert" \
    "$(node ngfw 'cat /var/log/suricata/fast.log 2>/dev/null')" 'LAB safe IDS alert'
expect_code "safe IPS marker is blocked only on scoped URI" internet-test 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://198.51.100.80/ids-block"
expect_code "normal request still passes beside IPS rule" internet-test 200 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 4 http://198.51.100.80/public-app"

expect_code "benign WAF marker receives deterministic deny" internet-test 403 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 4 'http://198.51.100.80/public-app?probe=LAB-WAF-SAFE-TEST'"
check_contains "WAF audit identifies the safe marker rule" \
    "$(node waf-pep 'cat /var/log/modsecurity/audit.log 2>/dev/null')" 'LAB safe WAF marker'

rate_before="$(node ngfw "nft list chain inet asa forward | sed -n 's/.*counter packets \\([0-9][0-9]*\\).*public WAF rate limit.*/\\1/p'")"
node internet-test "seq 1 120 | xargs -P60 -I{} curl -sS -o /dev/null --max-time 1 http://198.51.100.80/public-app >/dev/null 2>&1 || true"
rate_after="$(node ngfw "nft list chain inet asa forward | sed -n 's/.*counter packets \\([0-9][0-9]*\\).*public WAF rate limit.*/\\1/p'")"
if [[ -n "$rate_before" && -n "$rate_after" && "$rate_after" -gt "$rate_before" ]]; then
    pass "public rate limit drops only excess test burst"
else
    fail "public rate limit drops only excess test burst" "drop counter did not increase"
fi
sleep 1

check_contains "conntrack records translated public flow and reverse state" \
    "$(node ngfw 'conntrack -L -p tcp 2>/dev/null')" 'dst=198\.51\.100\.80.*src=10\.114\.30\.10'

expect_code "RTBH target is reachable before handoff" security-services 200 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://203.0.113.200:8080/attack-target"
expect_code "unauthorized RTBH request is rejected" security-services 403 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 -X POST -H 'Content-Type: application/json' -d '{\"prefix\":\"203.0.113.200/32\",\"ttl\":4}' http://198.51.100.1:9000/"
expect_code "allowlisted RTBH request is accepted" security-services 202 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 -X POST -H 'Authorization: Bearer LAB-ONLY-RTBH-CONTROL' -H 'Content-Type: application/json' -d '{\"prefix\":\"203.0.113.200/32\",\"ttl\":4}' http://198.51.100.1:9000/"
sleep 1
expect_code "RTBH blocks only selected documentation prefix" security-services 000 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 2 http://203.0.113.200:8080/attack-target"
expect_code "RTBH leaves approved documentation service reachable" security-services 200 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://203.0.113.80:8080/approved"
sleep 4
expect_code "RTBH route expires and target recovers" security-services 200 \
    "curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://203.0.113.200:8080/attack-target"

node partner "logger -n 10.114.60.10 -P 514 -d -t policy-probe 'event=$event_id-partner-bypass control=path-test decision=deny source=10.114.40.10 destination=10.114.20.20:8080'" || true
sleep 1
central_log="$(node security-services 'cat /var/log/asa/central.log 2>/dev/null')"
check_contains "central log correlates WAF event ID" "$central_log" "event=$event_id control=waf"
check_contains "central log correlates origin event ID" "$central_log" "event=$event_id action=http"
check_contains "central log records identity permit" "$central_log" "event=$event_id-partner decision=permit"
check_contains "central log records identity deny" "$central_log" "event=$event_id-partner-deny decision=deny"
check_contains "central log records independent firewall-path denial probe" "$central_log" "event=$event_id-partner-bypass.*decision=deny"
check_contains "central log records RTBH install and expiry" "$central_log" 'action=clear prefix=203\.0\.113\.200/32'
check_contains "DNS decisions carry source and query" "$central_log" 'dnsmasq.*query\[A\].*approved\.test.*10\.114\.10\.10'
check_contains "proxy decisions carry source and destination" \
    "$(node security-services 'cat /var/log/squid/access.log 2>/dev/null')" '10\.114\.10\.10.*approved\.test:8080'

summary
