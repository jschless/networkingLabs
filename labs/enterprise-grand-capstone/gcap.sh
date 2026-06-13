#!/usr/bin/env bash
# gcap.sh — orchestrate the Enterprise Grand Capstone (two tooling stacks).
#
# The lab is a Docker Compose services stack (services/) PLUS a ContainerLab
# campus (topology.clab.yml), bonded over the pinned `br-eitcorp` Linux bridge.
# They must come up in the right order; this wrapper hides the plumbing.
#
#   ./gcap.sh build     build gcap-node:local + ensure EIT101 images exist
#   ./gcap.sh deploy    services up -> clab deploy -> inject return-routes
#   ./gcap.sh destroy   clab destroy -> services down -v
#   ./gcap.sh status    show both stacks
#   ./gcap.sh routes    (re)inject the service->campus return-routes
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
EIT="$DIR/../../enterprise-it-101"
SEAM_VIP="10.100.254.1"
CAMPUS_SUBNETS=(10.10.10.0/24 10.20.20.0/24 10.30.30.0/24 192.168.99.0/24)
SERVICES=(dc1 dns1 radius1 dhcp1)

compose() { docker compose -f services/docker-compose.yml "$@"; }

inject_routes() {
    # EIT101 service containers default-route to the docker host; teach each one
    # the campus subnets via the collapsed-core seam VIP (same lab-corp L2), so
    # replies to campus clients don't depend on a host route.
    echo ">> injecting service->campus return-routes via $SEAM_VIP"
    for svc in "${SERVICES[@]}"; do
        for net in "${CAMPUS_SUBNETS[@]}"; do
            docker exec "$svc" ip route replace "$net" via "$SEAM_VIP" 2>/dev/null \
                && echo "   $svc: $net via $SEAM_VIP" \
                || echo "   $svc: FAILED $net (container not up / no NET_ADMIN?)"
        done
    done
}

case "${1:-help}" in
  build)
    echo ">> building gcap-node:local"
    DEBIAN_FRONTEND=noninteractive docker build -t gcap-node:local "$DIR"
    echo ">> ensuring EIT101 images (samba-ad, freeradius-ad, bind9, kea)"
    ( cd "$EIT" && ./eit.sh build samba-ad freeradius-ad bind9 kea )
    echo ">> NOTE: cEOS image ceos:4.35.2F must already be imported (see docs)."
    ;;

  deploy)
    echo ">> [1/3] bringing up services (creates br-eitcorp)"
    compose up -d
    echo ">> waiting for br-eitcorp bridge..."
    for i in $(seq 1 30); do ip link show br-eitcorp &>/dev/null && break; sleep 1; done
    ip link show br-eitcorp &>/dev/null || { echo "ERROR: br-eitcorp not created"; exit 1; }
    echo ">> [2/3] deploying ContainerLab campus"
    containerlab deploy -t topology.clab.yml
    echo ">> [3/3] waiting for services + injecting return-routes"
    sleep 5
    inject_routes
    echo ">> done. dc1 may still be provisioning the domain (~30-60s)."
    echo "   Verify:  ./gcap.sh status   then follow README.md"
    ;;

  destroy)
    echo ">> destroying ContainerLab campus"
    containerlab destroy -t topology.clab.yml --cleanup || true
    echo ">> tearing services down (with volumes)"
    compose down -v || true
    ;;

  routes)  inject_routes ;;

  status)
    echo "===== ContainerLab campus ====="
    containerlab inspect -t topology.clab.yml 2>/dev/null || echo "(not deployed)"
    echo "===== Compose services ====="
    compose ps 2>/dev/null || echo "(not up)"
    ;;

  *)
    grep -E '^#( |$)|^  \./gcap\.sh' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac
