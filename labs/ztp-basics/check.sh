#!/usr/bin/env bash
# Asserts the SOLVED end state of ztp-basics: sw1 was provisioned by ZTP
# (not by hand) and the served config is live and forwarding.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ztp-basics"

# The provisioning service is up
check_contains "dnsmasq running on ztp1" "$(node ztp1 'pgrep -a dnsmasq')" "dnsmasq"
check_contains "http server running on ztp1" "$(node ztp1 'pgrep -af http.server')" "8000"

# ZTP actually happened: the switch fetched the config over HTTP
check_contains "ztp1 served the config (HTTP 200)" "$(node ztp1 'cat /var/log/http.log 2>/dev/null')" "GET /startup-config HTTP/1.1\" 200"

# The served config is live on sw1 (hostname must differ from the node
# name — "sw1" is the container's default hostname and proves nothing)
check_contains "sw1 hostname provisioned" "$(eos sw1 'show hostname')" "Hostname: branch-sw1"
check_contains "sw1 banner marker" "$(eos sw1 'show banner motd')" "PROVISIONED-BY-ZTP"

# EOS wrote its own "ZTP done" marker back to flash
check_contains "flash restored (zerotouch-config back)" "$(node sw1 'ls /mnt/flash')" "zerotouch-config"
check_contains "flash restored (startup-config back)" "$(node sw1 'ls /mnt/flash')" "startup-config"

# The provisioned switch forwards: user segment reaches the ZTP server
check_ping_linux "h1 → ztp1 through provisioned sw1" h1 10.0.99.10

summary
