#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-dmz"

# Internal LAN → DMZ
check_ping_linux "workstation→web-server" workstation 172.16.0.2
check_ping_linux "workstation→mail-server" workstation 172.16.0.6
# DMZ servers reachable from internet side
check_ping_linux "internet-client→web-server" internet-client 172.16.0.2

summary
