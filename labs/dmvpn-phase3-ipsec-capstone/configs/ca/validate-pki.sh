#!/bin/sh
# Secret-safe semantic validation for the generated PKI workspace.
set -eu

base=/lab/pki
ca_key="$base/private/dmvpn-ca.key"
ca_cert="$base/ca/dmvpn-ca.pem"

fail() { echo "ERROR: PKI validation failed" >&2; exit 1; }
[ -f "$base/.complete" ] && [ "$(stat -c %a "$base")" = 700 ] || fail
[ -f "$ca_key" ] && [ -f "$ca_cert" ] || fail
[ "$(stat -c %a "$ca_key")" = 600 ] || fail
openssl pkey -in "$ca_key" -check -noout >/dev/null 2>&1 || fail
openssl verify -CAfile "$ca_cert" "$ca_cert" >/dev/null 2>&1 || fail
ca_text=$(openssl x509 -in "$ca_cert" -noout -subject -issuer -text)
printf '%s\n' "$ca_text" | grep -qE 'CN ?= ?DMVPN Capstone Root CA' || fail
printf '%s\n' "$ca_text" | grep -q 'CA:TRUE, pathlen:0' || fail
printf '%s\n' "$ca_text" | grep -q 'Certificate Sign, CRL Sign' || fail
printf '%s\n' "$ca_text" | grep -q 'Subject Key Identifier' || fail
printf '%s\n' "$ca_text" | grep -q 'Authority Key Identifier' || fail
ca_key_pub=$(openssl pkey -in "$ca_key" -pubout 2>/dev/null | openssl sha256)
ca_cert_pub=$(openssl x509 -in "$ca_cert" -pubkey -noout 2>/dev/null | openssl sha256)
[ "$ca_key_pub" = "$ca_cert_pub" ] || fail
ca_ski=$(openssl x509 -in "$ca_cert" -noout -ext subjectKeyIdentifier | tail -1 | tr -d '[:space:]')
ca_aki=$(openssl x509 -in "$ca_cert" -noout -ext authorityKeyIdentifier | tail -1 | tr -d '[:space:]')
[ -n "$ca_ski" ] && [ "$ca_ski" = "$ca_aki" ] || fail

[ "${1:-}" = --ca-only ] && exit 0
if [ "${1:-}" = --all ]; then
    for identity in hub spoke1 spoke2 spoke3; do
        "$0" "$identity" >/dev/null || fail
    done
    actual=$(cd "$base" && find . -type f | sed 's#^\./##' | sort)
    expected=$(cat <<'EOF'
.complete
ca.ext
ca/dmvpn-ca.pem
certs/hub.pem
certs/spoke1.pem
certs/spoke2.pem
certs/spoke3.pem
csr/hub.csr
csr/spoke1.csr
csr/spoke2.csr
csr/spoke3.csr
ext/hub.ext
ext/spoke1.ext
ext/spoke2.ext
ext/spoke3.ext
private/dmvpn-ca.key
private/hub.key
private/spoke1.key
private/spoke2.key
private/spoke3.key
EOF
)
    [ "$actual" = "$expected" ] || fail
    exit 0
fi
router=${1:-}
case "$router" in
    hub) fqdn=hub.dmvpn.lab; serial=03E9 ;;
    spoke1) fqdn=spoke1.dmvpn.lab; serial=03EA ;;
    spoke2) fqdn=spoke2.dmvpn.lab; serial=03EB ;;
    spoke3) fqdn=spoke3.dmvpn.lab; serial=03EC ;;
    *) fail ;;
esac
key="$base/private/$router.key"
csr="$base/csr/$router.csr"
cert="$base/certs/$router.pem"
ext="$base/ext/$router.ext"
for path in "$key" "$csr" "$cert" "$ext"; do
    [ -f "$path" ] && [ "$(stat -c %a "$path")" = 600 ] || fail
done
openssl pkey -in "$key" -check -noout >/dev/null 2>&1 || fail
openssl req -in "$csr" -verify -noout >/dev/null 2>&1 || fail
openssl verify -purpose sslclient -CAfile "$ca_cert" "$cert" >/dev/null 2>&1 || fail
openssl verify -purpose sslserver -CAfile "$ca_cert" "$cert" >/dev/null 2>&1 || fail
text=$(openssl x509 -in "$cert" -noout -subject -issuer -text)
printf '%s\n' "$text" | grep -qE "CN ?= ?$fqdn" || fail
printf '%s\n' "$text" | grep -q 'CA:FALSE' || fail
printf '%s\n' "$text" | grep -q 'Digital Signature, Key Encipherment' || fail
printf '%s\n' "$text" | grep -q 'TLS Web Server Authentication, TLS Web Client Authentication' || fail
printf '%s\n' "$text" | grep -q "DNS:$fqdn" || fail
printf '%s\n' "$text" | grep -q 'Subject Key Identifier' || fail
printf '%s\n' "$text" | grep -q 'Authority Key Identifier' || fail
key_pub=$(openssl pkey -in "$key" -pubout 2>/dev/null | openssl sha256)
cert_pub=$(openssl x509 -in "$cert" -pubkey -noout 2>/dev/null | openssl sha256)
[ "$key_pub" = "$cert_pub" ] || fail
csr_pub=$(openssl req -in "$csr" -pubkey -noout 2>/dev/null | openssl sha256)
[ "$key_pub" = "$csr_pub" ] || fail
csr_text=$(openssl req -in "$csr" -noout -subject -text)
printf '%s\n' "$csr_text" | grep -qE "CN ?= ?$fqdn" || fail
printf '%s\n' "$csr_text" | grep -q "DNS:$fqdn" || fail
leaf_aki=$(openssl x509 -in "$cert" -noout -ext authorityKeyIdentifier | tail -1 | tr -d '[:space:]')
[ "$leaf_aki" = "$ca_ski" ] || fail
[ "$(openssl x509 -in "$cert" -noout -serial | cut -d= -f2)" = "$serial" ] || fail
expected_ext=$(cat <<EOF
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = DNS:$fqdn
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF
)
[ "$(cat "$ext")" = "$expected_ext" ] || fail
exit 0
