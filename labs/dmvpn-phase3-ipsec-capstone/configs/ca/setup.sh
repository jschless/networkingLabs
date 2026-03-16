#!/bin/sh
set -e

mkdir -p /lab/pki
cp /lab/init-ca.sh /lab/pki/init-ca.sh
cp /lab/issue-router.sh /lab/pki/issue-router.sh
chmod +x /lab/pki/init-ca.sh /lab/pki/issue-router.sh

echo "[ca] Ready: run /lab/pki/init-ca.sh to create the PKI workspace"
