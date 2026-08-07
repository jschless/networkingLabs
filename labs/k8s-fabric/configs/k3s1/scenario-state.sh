#!/bin/sh
# Narrow state transition used by break.sh and solution.sh. Output is kept
# inside the node so the learner starts from symptoms, not the mutation.
set -eu

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

wait_for_web() {
    kubectl rollout status deployment/web --timeout=180s >/dev/null
    kubectl wait --for=condition=Ready pod -l app=web \
        --timeout=180s >/dev/null
}

case "${1:-}" in
    break)
        kubectl patch service web-lb --type=merge \
            -p '{"spec":{"externalTrafficPolicy":"Local"}}' >/dev/null
        kubectl patch deployment web --type=merge \
            -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k3s1"}}}}}' \
            >/dev/null
        wait_for_web
        ;;
    repair)
        kubectl patch service web-lb --type=merge \
            -p '{"spec":{"externalTrafficPolicy":"Cluster"}}' >/dev/null
        kubectl patch deployment web --type=merge \
            -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}' \
            >/dev/null
        wait_for_web
        ;;
    *)
        echo "usage: $0 break|repair" >&2
        exit 2
        ;;
esac
