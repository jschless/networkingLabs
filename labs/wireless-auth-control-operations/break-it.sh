#!/usr/bin/env bash
# Deliberately replace only the RADIUS server certificate. The trusted client CA
# remains intact, so a corporate client must reject this server instead of
# accepting it through a disabled-validation shortcut.
set -euo pipefail
lab=wireless-auth-control-operations
radius="clab-${lab}-radius"
corp="clab-${lab}-corp-client"

docker exec "$radius" bash -lc '
  pkill freeradius || true
  install -o freerad -g freerad -m 0644 /opt/lab-pki/untrusted/server.pem /etc/freeradius/3.0/certs/server.pem
  install -o freerad -g freerad -m 0640 /opt/lab-pki/untrusted/server.key /etc/freeradius/3.0/certs/server.key
  freeradius -XC >/var/log/freeradius/config-check.log
  : > /var/log/freeradius/debug.log
  nohup freeradius -X -f > /var/log/freeradius/debug.log 2>&1 &
'
docker exec "$corp" bash -lc '
  pkill wpa_supplicant || true
  : > /var/log/wpa-corp.log
  wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/corp.conf -B -P /run/wpa-corp.pid -f /var/log/wpa-corp.log
'
echo "Break-It active: the corporate client should report certificate validation failure."
