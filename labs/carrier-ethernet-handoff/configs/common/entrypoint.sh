#!/usr/bin/env bash
set -euo pipefail

if [[ "${ROLE:-tester}" == "nid" || "${ROLE:-tester}" == "core" ]]; then
  mkdir -p /var/run/openvswitch
  ovsdb-tool create /etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
  ovsdb-server --remote=punix:/var/run/openvswitch/db.sock --pidfile --detach
  ovs-vsctl --no-wait init
  ovs-vswitchd --pidfile --detach --disable-system unix:/var/run/openvswitch/db.sock
fi

exec sleep infinity
