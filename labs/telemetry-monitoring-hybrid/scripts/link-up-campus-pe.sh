#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

campus="$(node_name campus1)"

echo "Restoring campus1 Ethernet2"
docker exec "${campus}" bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nno shutdown\nend\n' | Cli"
