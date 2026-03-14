#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

campus="$(node_name campus1)"

echo "Shutting campus1 Ethernet2"
docker exec "${campus}" bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nshutdown\nend\n' | Cli"
