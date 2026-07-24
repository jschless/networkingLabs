#!/usr/bin/env bash
set -euo pipefail
NODE="${1:?usage: revoke.sh edge-name}"
CERT="/runtime/edges/$NODE/client.crt"
[[ -s "$CERT" ]] || { echo "no enrolled certificate for $NODE" >&2; exit 1; }
openssl x509 -in "$CERT" -noout -serial | cut -d= -f2 >> /runtime/pki/revoked.serials
sort -u -o /runtime/pki/revoked.serials /runtime/pki/revoked.serials
echo "revoked $NODE serial $(tail -1 /runtime/pki/revoked.serials)"
