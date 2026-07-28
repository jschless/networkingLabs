#!/usr/bin/env bash
set -euo pipefail
name=clab-advanced-security-architecture-ngfw
handle="$(
    docker exec "$name" nft -a list chain inet asa forward |
        awk '/BREAKIT broad partner origin bypass/ {print $NF; exit}'
)"
if [[ -z "$handle" ]]; then
    echo "Break-It rule is not present."
    exit 0
fi
docker exec "$name" nft delete rule inet asa forward handle "$handle"
echo "Removed only the shadowing rule (handle $handle)."
