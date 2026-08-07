#!/usr/bin/env bash
# Validate the learned native VyOS QoS policy and fresh differentiated traffic.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "qos-enterprise"

container() {
    printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"
}

container_image() {
    docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null
}

safe_node() {
    docker exec "$(container "$1")" sh -c "$2" 2>/dev/null
}

normalized_qos() {
    sed -E "s/'//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | LC_ALL=C sort
}

class_bytes() {
    local handle="$1" state="$2"
    awk -v handle="$handle" '
        $1 == "class" { wanted = ($3 == handle) }
        wanted && $1 == "Sent" { print $2; exit }
    ' <<<"$state"
}

class_stat() {
    local handle="$1" key="$2" state="$3"
    awk -v handle="$handle" -v key="$key" '
        $1 == "class" { wanted = ($3 == handle) }
        wanted {
            for (i = 1; i <= NF; i++) {
                field = $i
                gsub(/:$/, "", field)
                if (field == key && (i + 1) <= NF) {
                    print $(i + 1)
                    exit
                }
            }
        }
    ' <<<"$state"
}

filter_rule_matches() {
    local match_value="$1" flowid="$2" police_rate="$3" state="$4"
    awk -v match_value="$match_value" -v flowid="$flowid" \
        -v police_rate="$police_rate" '
        BEGIN { RS = "filter parent"; found = 0 }
        index($0, "match " match_value " at 0") &&
        index($0, "flowid " flowid) &&
        index($0, "rate " police_rate) &&
        index($0, "action reclassify") { found = 1 }
        END { exit !found }
    ' <<<"$state"
}

red_drops() {
    local state="$1"
    awk '
        $1 == "qdisc" {
            wanted = ($2 == "red" && $0 ~ / parent 1:15([[:space:]]|$)/)
        }
        wanted && match($0, /\(dropped [0-9]+,/) {
            value = substr($0, RSTART + 9, RLENGTH - 10)
            print value
            exit
        }
    ' <<<"$state"
}

metric() {
    local name="$1" data="$2"
    awk -F= -v name="$name" '$1 == name { print $2; exit }' <<<"$data"
}

actual_nodes="$(docker ps --format '{{.Names}}' | sed -n \
    "s/^clab-${TOPO_NAME}-//p" | LC_ALL=C sort)"
expected_nodes=$'client-data\nclient-video\nclient-voice\nrouter\nserver'
if [[ "$actual_nodes" == "$expected_nodes" ]]; then
    pass "inventory contains exactly the five intended nodes"
else
    fail "inventory contains exactly the five intended nodes" \
        "running inventory differs from the required topology"
fi

check_contains "router uses the native VyOS image" \
    "$(container_image router)" '^vyos:local$'

endpoint_images="$(for endpoint in client-data client-video client-voice server; do
    container_image "$endpoint"
done)"
if [[ "$endpoint_images" == $'qos-lab:local\nqos-lab:local\nqos-lab:local\nqos-lab:local' ]]; then
    pass "all four incidental endpoints use qos-lab:local"
else
    fail "all four incidental endpoints use qos-lab:local" \
        "endpoint image inventory differs from the topology contract"
fi

voice_addresses="$(safe_node client-voice 'ip -4 -o address show dev eth1')"
video_addresses="$(safe_node client-video 'ip -4 -o address show dev eth1')"
data_addresses="$(safe_node client-data 'ip -4 -o address show dev eth1')"
server_addresses="$(safe_node server 'ip -4 -o address show dev eth1')"
router_addresses="$(safe_node router 'ip -4 -o address show')"

check_contains "voice source addressing is exact" "$voice_addresses" \
    'eth1[[:space:]]+inet 10\.1\.1\.1/30'
check_contains "video source addressing is exact" "$video_addresses" \
    'eth1[[:space:]]+inet 10\.1\.2\.1/30'
check_contains "bulk source addressing is exact" "$data_addresses" \
    'eth1[[:space:]]+inet 10\.1\.3\.1/30'
check_contains "receiver addressing is exact" "$server_addresses" \
    'eth1[[:space:]]+inet 10\.2\.0\.2/30'

router_address_contract=true
for address in \
    'eth1[[:space:]]+inet 10\.1\.1\.2/30' \
    'eth2[[:space:]]+inet 10\.1\.2\.2/30' \
    'eth3[[:space:]]+inet 10\.1\.3\.2/30' \
    'eth4[[:space:]]+inet 10\.2\.0\.1/30'; do
    grep -qE "$address" <<<"$router_addresses" || router_address_contract=false
done
if [[ "$router_address_contract" == true ]]; then
    pass "VyOS data interfaces have the four exact link addresses"
else
    fail "VyOS data interfaces have the four exact link addresses" \
        "router data-interface addressing differs from the topology contract"
fi

route_contract=true
for item in \
    'client-voice|10.1.1.2' \
    'client-video|10.1.2.2' \
    'client-data|10.1.3.2' \
    'server|10.2.0.1'; do
    node_name=${item%%|*}
    gateway=${item##*|}
    route="$(safe_node "$node_name" 'ip -4 route show default')"
    grep -qE "^default via ${gateway//./\\.} dev eth1([[:space:]]|$)" \
        <<<"$route" || route_contract=false
done
if [[ "$route_contract" == true ]]; then
    pass "every endpoint has the exact routed default path"
else
    fail "every endpoint has the exact routed default path" \
        "one or more endpoint routes differ from the topology contract"
fi

listener_state="$(safe_node server 'ss -lnt')"
listener_contract=true
for port in 5201 5202 5203; do
    grep -qE ":${port}[[:space:]]" <<<"$listener_state" || listener_contract=false
done
if [[ "$listener_contract" == true ]]; then
    pass "three independent bounded-offer receivers are listening"
else
    fail "three independent bounded-offer receivers are listening" \
        "the three-port receiver scaffold is incomplete"
fi

config="$(vyos_op router 'show configuration commands')"
qos_config="$(grep '^set qos ' <<<"$config" | normalized_qos)"
qos_digest="$(printf '%s\n' "$qos_config" | sha256sum | awk '{print $1}')"
if [[ "$qos_digest" == \
    "30c8472a8c341117ec40b1797b13ef6ad82638af87a3bc1e0dc6e07a5ab68d85" ]]; then
    pass "native VyOS learned policy matches the exact healthy definition"
else
    fail "native VyOS learned policy matches the exact healthy definition" \
        "learned state differs from the required exact definition"
fi
check_not_contains "the undifferentiated startup baseline is absent" "$config" \
    '^set qos policy rate-control|QOS-BASELINE'

saved_commands="$(safe_node router \
    '/usr/bin/vyos-config-to-commands /config/config.boot')"
saved_qos="$(grep '^set qos ' <<<"$saved_commands" | normalized_qos)"
saved_qos_digest="$(printf '%s\n' "$saved_qos" | sha256sum | awk '{print $1}')"
if [[ "$saved_qos_digest" == \
    "30c8472a8c341117ec40b1797b13ef6ad82638af87a3bc1e0dc6e07a5ab68d85" ]]; then
    pass "saved VyOS policy matches the exact healthy definition"
else
    fail "saved VyOS policy matches the exact healthy definition" \
        "saved learned state differs from the required healthy reference"
fi

qdisc_before="$(safe_node router 'tc -s qdisc show dev eth4')"
class_before="$(safe_node router 'tc -s class show dev eth4')"
filter_before="$(safe_node router 'tc -s filter show dev eth4')"
lower_qdisc="$(tr '[:upper:]' '[:lower:]' <<<"$qdisc_before")"
lower_class="$(tr '[:upper:]' '[:lower:]' <<<"$class_before")"
lower_filter="$(tr '[:upper:]' '[:lower:]' <<<"$filter_before")"

check_contains "VyOS rendered the 2 Mbit/s HTB root" "$lower_qdisc" \
    '^qdisc htb 1: root .*default 0x15'

class_contract=true
grep -qE '^class htb 1:1 root .*rate 2mbit ceil 2mbit' \
    <<<"$lower_class" || class_contract=false
grep -qE '^class htb 1:a parent 1:1 .*rate 800kbit ceil 800kbit' \
    <<<"$lower_class" || class_contract=false
grep -qE '^class htb 1:14 parent 1:1 .*rate 600kbit ceil 2mbit' \
    <<<"$lower_class" || class_contract=false
grep -qE '^class htb 1:15 parent 1:1 .*rate 600kbit ceil 2mbit' \
    <<<"$lower_class" || class_contract=false
if [[ "$class_contract" == true ]]; then
    pass "kernel HTB classes implement the exact bandwidth contract"
else
    fail "kernel HTB classes implement the exact bandwidth contract" \
        "kernel class state differs from the learned policy"
fi

leaf_contract=true
grep -qE '^qdisc pfifo .* parent 1:a ' <<<"$lower_qdisc" || leaf_contract=false
grep -qE '^qdisc sfq .* parent 1:14 ' <<<"$lower_qdisc" || leaf_contract=false
grep -qE '^qdisc red .* parent 1:15 ' <<<"$lower_qdisc" || leaf_contract=false
if [[ "$leaf_contract" == true ]]; then
    pass "kernel leaves are drop-tail, SFQ, and RED on the intended classes"
else
    fail "kernel leaves are drop-tail, SFQ, and RED on the intended classes" \
        "kernel queue state differs from the learned treatments"
fi

filter_contract=true
filter_rule_matches '00b80000/00ff0000' '1:a' '800kbit' \
    "$lower_filter" || filter_contract=false
filter_rule_matches '00880000/00ff0000' '1:14' '600kbit' \
    "$lower_filter" || filter_contract=false
if [[ "$filter_contract" == true ]]; then
    pass "kernel classifiers enforce the intended DSCP admission behavior"
else
    fail "kernel classifiers enforce the intended DSCP admission behavior" \
        "kernel classifier state differs from the learned policy"
fi

traffic_output="$($REPO_ROOT/labs/qos-enterprise/traffic-test.sh --machine 2>/dev/null)"
traffic_status=$?
class_after="$(safe_node router 'tc -s class show dev eth4')"
qdisc_after="$(safe_node router 'tc -s qdisc show dev eth4')"

counter_contract=true
for handle in 1:a 1:14 1:15; do
    before="$(class_bytes "$handle" "$class_before")"
    after="$(class_bytes "$handle" "$class_after")"
    if [[ ! "$before" =~ ^[0-9]+$ || ! "$after" =~ ^[0-9]+$ ]] ||
       (( after <= before )); then
        counter_contract=false
    fi
done
if [[ "$traffic_status" -eq 0 && "$counter_contract" == true ]]; then
    pass "fresh DSCP offers increment all three intended class counters"
else
    fail "fresh DSCP offers increment all three intended class counters" \
        "fresh traffic did not reach every intended class"
fi

video_borrowed_before="$(class_stat 1:14 borrowed "$class_before")"
video_borrowed_after="$(class_stat 1:14 borrowed "$class_after")"
default_borrowed_before="$(class_stat 1:15 borrowed "$class_before")"
default_borrowed_after="$(class_stat 1:15 borrowed "$class_after")"
if [[ "$traffic_status" -eq 0 &&
      "$video_borrowed_before" =~ ^[0-9]+$ &&
      "$video_borrowed_after" =~ ^[0-9]+$ &&
      "$default_borrowed_before" =~ ^[0-9]+$ &&
      "$default_borrowed_after" =~ ^[0-9]+$ ]] &&
   (( video_borrowed_after == video_borrowed_before &&
      default_borrowed_after > default_borrowed_before )); then
    pass "fresh contention follows the rendered reclassification path"
else
    fail "fresh contention follows the rendered reclassification path" \
        "fresh class behavior differs from the validated renderer outcome"
fi

red_drops_before="$(red_drops "$qdisc_before")"
red_drops_after="$(red_drops "$qdisc_after")"
if [[ "$traffic_status" -eq 0 && "$red_drops_before" =~ ^[0-9]+$ &&
      "$red_drops_after" =~ ^[0-9]+$ ]] &&
   (( red_drops_after > red_drops_before )); then
    pass "fresh unmatched contention increments RED total drops"
else
    fail "fresh unmatched contention increments RED total drops" \
        "fresh RED drop behavior differs from the validated outcome"
fi

voice_loss="$(metric voice_loss_pct "$traffic_output")"
video_loss="$(metric video_loss_pct "$traffic_output")"
data_loss="$(metric data_loss_pct "$traffic_output")"
aggregate="$(metric aggregate_received_bps "$traffic_output")"

if [[ "$traffic_status" -eq 0 ]] && awk -v loss="$voice_loss" \
    'BEGIN { exit !(loss >= 0 && loss <= 5) }'; then
    pass "bounded contention protects the in-profile EF offer"
else
    fail "bounded contention protects the in-profile EF offer" \
        "fresh contention did not preserve the required EF outcome"
fi

if [[ "$traffic_status" -eq 0 ]] && awk \
    -v voice="$voice_loss" -v video="$video_loss" -v data="$data_loss" \
    'BEGIN { exit !(video >= 15 && video <= 75 && data >= 45 && data <= 90 &&
                     voice < video && video < data) }'; then
    pass "bounded contention produces differentiated class loss"
else
    fail "bounded contention produces differentiated class loss" \
        "fresh loss ordering is outside the validated envelope"
fi

if [[ "$traffic_status" -eq 0 ]] && awk -v rate="$aggregate" \
    'BEGIN { exit !(rate >= 1700000 && rate <= 2300000) }'; then
    pass "aggregate receiver throughput stays near the 2 Mbit/s shaper"
else
    fail "aggregate receiver throughput stays near the 2 Mbit/s shaper" \
        "fresh aggregate throughput is outside the validated envelope"
fi

check_ping_linux "voice source retains routed reachability" client-voice 10.2.0.2
check_ping_linux "video source retains routed reachability" client-video 10.2.0.2
check_ping_linux "bulk source retains routed reachability" client-data 10.2.0.2

summary
