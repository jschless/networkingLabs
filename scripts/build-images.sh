#!/usr/bin/env bash
#
# build-images.sh — provision every lab container image for THIS host's
# architecture (amd64 on Intel/Linux, arm64 on Apple Silicon).
#
# The whole point of this script is dual-arch portability: the same
# topology.clab.yml files run on either machine, and this script fills the
# image tags they reference with native-arch content. It does that three ways,
# one per image class:
#
#   1. multi-arch registry images  -> `docker pull` auto-selects the host arch
#   2. `*:local` images            -> `docker build` emits the host arch for free
#   3. cEOS (per-arch tarball)      -> import the arch-matching tarball, then tag
#                                      it as the canonical `ceos:4.35.2F` the
#                                      topologies reference (no multi-arch tag
#                                      exists for cEOS, so we normalise here)
#
# Usage:
#   scripts/build-images.sh              # do everything (build + pull + import)
#   scripts/build-images.sh local        # only the *:local build images
#   scripts/build-images.sh ceos         # only import/normalise cEOS
#   scripts/build-images.sh pull         # only the multi-arch registry pulls
#   scripts/build-images.sh list         # print what would run, do nothing
#
# Env:
#   CEOS_TARBALL_DIR   where to look for the cEOS tarball (default: ~/Downloads)
#   CEOS_TAG           canonical cEOS tag the topologies use (default: ceos:4.35.2F)
#
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root

CEOS_TAG="${CEOS_TAG:-ceos:4.35.2F}"
CEOS_TARBALL_DIR="${CEOS_TARBALL_DIR:-$HOME/Downloads}"

# --- host architecture -------------------------------------------------------
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=amd64 ;;
  *) echo "!! unknown arch $(uname -m); assuming amd64" >&2; ARCH=amd64 ;;
esac

if [[ -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  echo "!! DOCKER_DEFAULT_PLATFORM=$DOCKER_DEFAULT_PLATFORM is set — this can force the"
  echo "!! wrong architecture and defeat native selection. Consider 'unset DOCKER_DEFAULT_PLATFORM'." >&2
fi

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*" >&2; }

# --- the *:local build images ------------------------------------------------
# Each entry is the argument string passed to `docker build`. Building on this
# host produces native-arch images automatically.  (vyos:local is intentionally
# absent — it is built from a VyOS ISO you supply; see docs/platforms/vyos.md.)
LOCAL_BUILDS=(
  "-t frr-lab:local images/frr/"
  "-t ipsec-lab:local labs/ipsec-basics/"
  "-t wireguard-lab:local labs/wireguard/"
  "-t black-core-tools:local labs/black-core-routing/"
  "-t ops-lab:local images/ops-lab/"
  "-t nac-lab:local labs/dot1x-nac/"
  "-t nac-practice:local labs/dot1x-ceos-practice/"
  "-t assurance-lab:local labs/network-assurance/"
  "-t qos-lab:local labs/qos-enterprise/"
  "-t telemetry-lab:local labs/telemetry-monitoring-hybrid/"
  "-t sdwan-lab:local labs/sdwan-concepts/"
  "-t orchestrated-wan-tools:1.0.0 labs/orchestrated-wan-overlay/"
  "-t automation-fundamentals:local labs/automation-fundamentals/"
  "-t lb-lab:local labs/load-balancer-basics/"
  "-t global-delivery:local labs/global-application-delivery/"
  "-t anycast-dns:local labs/anycast-dns/"
  "-t service-ha:local labs/service-ha/"
  "-t netbox-automation:local labs/network-automation-netbox/"
  "-t opnsense-tools:local labs/opnsense-ngfw-basics/"
  "-t enterprise-services-infra:local labs/enterprise-services-infra/"
  "-t enterprise-access-tools:local labs/enterprise-access-security/"
  "-t enterprise-multicast:local labs/enterprise-multicast/"
  "-t enterprise-wireless-architecture:local labs/enterprise-wireless-architecture/"
  "-t dmz-lab:local labs/enterprise-edge-nat-firewall/"
  "-t gcap-node:local labs/enterprise-grand-capstone/"
  "-t suzieq-lab:local labs/suzieq-network-observability/"
  "-t soc-attacker:local images/soc-attacker/"
  "-t soc-endpoint:local images/soc-endpoint/"
  "-t soc-sensor:local images/soc-sensor/"
)

# TACACS helper images build FROM smcline06/tacacs:latest, which is amd64-only.
# They build and run on arm64 under emulation — fine for a light auth daemon,
# just slower. Listed separately so we can warn.
TACACS_BUILDS=(
  "-f labs/dot1x-ceos-practice/Dockerfile.tacacs -t nac-practice-tacacs:local labs/dot1x-ceos-practice/"
  "-f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/"
)

# --- multi-arch registry images ----------------------------------------------
PULLS=(
  "ghcr.io/nokia/srlinux:latest"
  "rancher/k3s:v1.30.6-k3s1"
)

build_local() {
  info "Building *:local images natively for $ARCH"
  for args in "${LOCAL_BUILDS[@]}"; do
    info "docker build $args"
    # shellcheck disable=SC2086
    docker build $args
  done
  warn "The next two images build from an amd64-only TACACS base."
  [[ "$ARCH" == arm64 ]] && warn "On $ARCH they will be emulated (slow but functional)."
  for args in "${TACACS_BUILDS[@]}"; do
    info "docker build $args"
    # shellcheck disable=SC2086
    docker build $args
  done
  warn "vyos:local is NOT built here — supply a VyOS ISO for your arch and run"
  warn "  docker build -t vyos:local -f Dockerfile.vyos .   (see docs/platforms/vyos.md)"
}

pull_public() {
  info "Pulling multi-arch registry images (Docker auto-selects $ARCH)"
  for img in "${PULLS[@]}"; do
    info "docker pull $img"
    docker pull "$img"
  done
}

import_ceos() {
  info "Normalising cEOS to $CEOS_TAG for $ARCH"
  # Arista ships cEOS as a per-arch filesystem tarball (NOT a docker-load image
  # and NOT a multi-arch manifest). We import whichever matches this host and
  # tag it canonically so all ~70 cEOS topologies work unchanged on both hosts.
  local pattern tarball
  if [[ "$ARCH" == arm64 ]]; then
    pattern='cEOSarm*.tar'      # e.g. cEOSarm-lab-4.36.1F.tar
  else
    pattern='cEOS-lab-*.tar cEOS64-lab-*.tar'  # e.g. cEOS-lab-4.35.2F.tar
  fi
  tarball=""
  for p in $pattern; do
    # shellcheck disable=SC2086
    local match; match=$(ls -1t "$CEOS_TARBALL_DIR"/$p 2>/dev/null | head -1 || true)
    [[ -n "$match" ]] && { tarball="$match"; break; }
  done
  if [[ -z "$tarball" ]]; then
    warn "No cEOS tarball for $ARCH found in $CEOS_TARBALL_DIR (looked for: $pattern)."
    warn "Download it from https://www.arista.com/en/support/software-download (free"
    warn "account required), then re-run, or set CEOS_TARBALL_DIR=/path/to/dir."
    return 0
  fi
  info "Importing $tarball -> $CEOS_TAG"
  docker import "$tarball" "$CEOS_TAG"
  local got; got=$(docker inspect --format '{{.Architecture}}' "$CEOS_TAG" 2>/dev/null || echo '?')
  info "cEOS imported ($CEOS_TAG, arch=$got). Note: on arm64 the underlying build"
  info "is 4.36.1F but tagged canonically as $CEOS_TAG so topologies stay portable."
}

list_plan() {
  echo "Host arch : $ARCH"
  echo "cEOS tag  : $CEOS_TAG   (tarball dir: $CEOS_TARBALL_DIR)"
  echo
  echo "Would build (*:local, native $ARCH):"
  for a in "${LOCAL_BUILDS[@]}" "${TACACS_BUILDS[@]}"; do echo "  docker build $a"; done
  echo "Would pull (multi-arch):"
  for i in "${PULLS[@]}"; do echo "  docker pull $i"; done
  echo "Would import cEOS from $CEOS_TARBALL_DIR"
}

case "${1:-all}" in
  all)   build_local; pull_public; import_ceos ;;
  local) build_local ;;
  pull)  pull_public ;;
  ceos)  import_ceos ;;
  list)  list_plan ;;
  *) echo "usage: $0 [all|local|pull|ceos|list]" >&2; exit 2 ;;
esac

info "Done."
