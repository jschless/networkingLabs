#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access

docker exec "$prefix-managed-client" \
    rm -f /run/range-client-certificate.env
