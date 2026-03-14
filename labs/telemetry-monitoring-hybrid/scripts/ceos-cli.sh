#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

node="${1:-}"

if [[ -z "${node}" ]]; then
    echo "Usage: $0 <campus1|core1>" >&2
    exit 1
fi

case "${node}" in
    campus1|core1) ;;
    *)
        echo "Only campus1 and core1 are cEOS nodes in this lab." >&2
        exit 1
        ;;
esac

docker exec -it "$(node_name "${node}")" Cli
