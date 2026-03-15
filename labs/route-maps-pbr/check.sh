#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "route-maps-pbr"

# Both ISP routes should be reachable from router
check_ping_linux "router→isp1" router 10.99.1.1
check_ping_linux "router→isp2" router 10.99.2.1
# host-a traffic goes via isp1 (PBR)
check_ping_linux "host-a→isp1" host-a 10.99.1.1
# host-b traffic goes via isp2 (PBR)
check_ping_linux "host-b→isp2" host-b 10.99.2.1

summary
