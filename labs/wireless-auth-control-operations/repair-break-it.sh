#!/usr/bin/env bash
# Minimal repair: restore the intended CA-signed server certificate. Do not
# remove ca_cert or domain_suffix_match from the client configuration.
set -euo pipefail
lab=wireless-auth-control-operations
radius="clab-${lab}-radius"
corp="clab-${lab}-corp-client"
quarantine="clab-${lab}-quarantine-client"

docker exec "$radius" bash -lc '
  pkill freeradius || true
  install -o freerad -g freerad -m 0644 /opt/lab-pki/golden/server.pem /etc/freeradius/3.0/certs/server.pem
  install -o freerad -g freerad -m 0640 /opt/lab-pki/golden/server.key /etc/freeradius/3.0/certs/server.key
  freeradius -XC >/var/log/freeradius/config-check.log
  : > /var/log/freeradius/debug.log
  nohup freeradius -X -f > /var/log/freeradius/debug.log 2>&1 &
'
docker exec "$corp" bash -lc '
  pkill wpa_supplicant || true
  : > /var/log/wpa-corp.log
  wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/corp.conf -B -P /run/wpa-corp.pid -f /var/log/wpa-corp.log
'
docker exec "$quarantine" bash -lc '
  pkill wpa_supplicant || true
  : > /var/log/wpa-quarantine.log
  wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/quarantine.conf -B -P /run/wpa-quarantine.pid -f /var/log/wpa-quarantine.log
'
echo "Golden RADIUS certificate restored; wait for EAP reauthentication before running check.sh."
