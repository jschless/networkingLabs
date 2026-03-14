#!/bin/bash
set -euo pipefail

lab_prefix() {
    if docker ps --format '{{.Names}}' | grep -q '^clab-telemetry-monitoring-full-'; then
        echo "clab-telemetry-monitoring-full"
        return 0
    fi
    if docker ps --format '{{.Names}}' | grep -q '^clab-telemetry-monitoring-lite-'; then
        echo "clab-telemetry-monitoring-lite"
        return 0
    fi

    echo "No telemetry-monitoring lab is running." >&2
    exit 1
}

require_full_profile() {
    local prefix
    prefix="$(lab_prefix)"
    if [[ "${prefix}" != "clab-telemetry-monitoring-full" ]]; then
        echo "This action requires the full profile." >&2
        exit 1
    fi
}

node_name() {
    local node="$1"
    echo "$(lab_prefix)-${node}"
}
