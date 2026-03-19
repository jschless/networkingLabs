#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "fortigate-firewall-capstone"

cat <<'EOF'
FortiGate manual validation required.

This lab cannot be automatically validated in this repo because the
`vrnetlab/vr-fortios:4.7.11` image requires manual license activation.

Run these checks after licensing and configuration:

1. FortiGate reachability
   - ssh -p 2222 admin@127.0.0.1
   - http://127.0.0.1:8080 or https://127.0.0.1:8443

2. CLI state
   - get system interface
   - get router info routing-table all
   - show firewall address
   - show firewall service group
   - show firewall vip
   - show firewall policy

3. Traffic tests
   - corp-client -> internet-client HTTP/HTTPS succeeds
   - guest-client -> internet-client DNS/HTTP/HTTPS succeeds
   - guest-client -> corp-client and db-server fails
   - internet-client -> 203.0.113.2 HTTP/HTTPS succeeds
   - internet-client -> corp-client and db-server fails
   - dmz-web -> db-server TCP/3306 succeeds

4. GUI validation
   - Firewall policy hit counts increment
   - Forward traffic logs show both accept and deny events
EOF

exit 2
