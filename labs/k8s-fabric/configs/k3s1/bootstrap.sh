#!/bin/sh
# One-time cluster bootstrap, launched in the background from the topology's
# k3s1 exec. Installs MetalLB (unconfigured — the student writes its BGP)
# and a sample workload. Idempotent-ish: safe to re-run.
#
# Progress + errors: /var/log/bootstrap.log inside k3s1.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
K() { kubectl "$@"; }

echo "[bootstrap] waiting for the API server..."
until K get nodes >/dev/null 2>&1; do sleep 3; done

echo "[bootstrap] waiting for both nodes Ready..."
until [ "$(K get nodes --no-headers 2>/dev/null | grep -cw Ready)" -ge 2 ]; do sleep 3; done

echo "[bootstrap] installing MetalLB (unconfigured)..."
K apply -f /manifests/metallb-native.yaml
K -n metallb-system rollout status deploy/controller --timeout=240s
K -n metallb-system rollout status daemonset/speaker --timeout=240s

echo "[bootstrap] deploying the sample workload (web, 4 replicas)..."
K apply -f /manifests/web.yaml
K rollout status deploy/web --timeout=240s

echo "[bootstrap] done — MetalLB running, no BGP config yet; web ready."
