#!/bin/sh
# Bounded, repeatable scaffolding bootstrap. MetalLB is installed but its
# peering and address resources remain learner-owned.
set -eu

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
K() { kubectl "$@"; }

diagnostics() {
    echo "[bootstrap] diagnostics: nodes" >&2
    K get nodes -o wide >&2 || true
    echo "[bootstrap] diagnostics: pods" >&2
    K get pods -A -o wide >&2 || true
    echo "[bootstrap] diagnostics: recent events" >&2
    K get events -A --sort-by=.metadata.creationTimestamp 2>/dev/null \
        | tail -n 40 >&2 || true
}

wait_for_api() {
    deadline=$(( $(date +%s) + 300 ))
    until K get --raw=/readyz >/dev/null 2>&1; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "[bootstrap] API readiness timed out after 300 seconds" >&2
            diagnostics
            return 1
        fi
        sleep 3
    done
}

wait_for_nodes() {
    deadline=$(( $(date +%s) + 300 ))
    while :; do
        ready="$(K get nodes --no-headers 2>/dev/null \
            | awk '$2 == "Ready" { count++ } END { print count + 0 }')"
        total="$(K get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
        [ "$ready" = 2 ] && [ "$total" = 2 ] && return 0
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "[bootstrap] two-node readiness timed out after 300 seconds" >&2
            diagnostics
            return 1
        fi
        sleep 3
    done
}

rollout() {
    description="$1"
    shift
    if ! K "$@" --timeout=300s; then
        echo "[bootstrap] $description did not become ready" >&2
        diagnostics
        return 1
    fi
}

echo "[bootstrap] waiting for the API server (300s bound)..."
wait_for_api
echo "[bootstrap] waiting for exactly two Ready nodes (300s bound)..."
wait_for_nodes

echo "[bootstrap] installing MetalLB (unconfigured)..."
K apply -f /manifests/metallb-native.yaml
rollout "MetalLB controller" -n metallb-system rollout status deploy/controller
rollout "MetalLB speakers" -n metallb-system rollout status daemonset/speaker

echo "[bootstrap] deploying the sample workload (web, 4 replicas)..."
K apply -f /manifests/web.yaml
rollout "web deployment" rollout status deploy/web

echo "[bootstrap] done — MetalLB running, no BGP config yet; web ready."
