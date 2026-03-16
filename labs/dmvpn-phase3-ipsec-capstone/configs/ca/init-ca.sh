#!/bin/sh
set -e

BASE="${1:-/lab/pki}"

mkdir -p "$BASE"/ca "$BASE"/certs "$BASE"/csr "$BASE"/private "$BASE"/install "$BASE"/ext
chmod 700 "$BASE/private"

: > "$BASE/index.txt"
echo 1000 > "$BASE/serial"

cat > "$BASE/README.txt" <<'EOF'
PKI workspace initialized.

Next steps:
1. Generate the CA key and certificate in private/ and ca/
2. Run ./issue-router.sh <router> <fqdn> for hub and every spoke
3. Copy or paste install/<router>.commands into the matching VyOS router
EOF

echo "Initialized PKI workspace at $BASE"
echo "Read $BASE/README.txt for the next steps."
