#!/usr/bin/env bash
set -euo pipefail
until [[ -s /runtime/pki/ca.crt ]]; do sleep 1; done
mkdir -p /runtime/controller
chmod -R a+rwx /runtime
if [[ ! -s /runtime/controller/controller.crt ]]; then
  openssl req -new -newkey rsa:2048 -nodes -keyout /runtime/controller/controller.key -out /tmp/controller.csr -subj '/CN=controller' >/dev/null 2>&1
  openssl x509 -req -in /tmp/controller.csr -CA /runtime/pki/ca.crt -CAkey /runtime/pki/ca.key -CAcreateserial -out /runtime/controller/controller.crt -days 1 -sha256 >/dev/null 2>&1
fi
[[ -s /runtime/controller/policy-version ]] || echo v1 > /runtime/controller/policy-version
touch /runtime/controller/audit.log
ip addr add 10.113.40.10/24 dev eth1
ip link set eth1 up
nohup python3 /controller.py >/tmp/controller.log 2>&1 &
